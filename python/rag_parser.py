import os
from langchain_community.document_loaders import WebBaseLoader, TextLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS

# ---------------- CONFIG ----------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FAISS_PATH = os.path.join(SCRIPT_DIR, "vlm", "faiss_index_apple")
CHUNK_SIZE = 600
CHUNK_OVERLAP = 120
TOP_K = 5

class DiagnosticRetriever:
    def __init__(self):
        self.embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
        self.vectorstore = self._load_vectorstore()
        self.retriever = self.vectorstore.as_retriever(search_kwargs={"k": TOP_K})

    def _load_vectorstore(self):
        if os.path.exists(FAISS_PATH):
            print(f"[INFO] Loading FAISS index from {FAISS_PATH}")
            return FAISS.load_local(FAISS_PATH, self.embeddings, allow_dangerous_deserialization=True)
        else:
            print(f"[WARNING] FAISS index not found at {FAISS_PATH}. Please run rag_parser.py as a script to build it.")
            # Return empty or dummy vectorstore? For now, we error out as the app depends on it.
            raise FileNotFoundError(f"FAISS index not found at {FAISS_PATH}")

    def get_context(self, query):
        print(f"[INFO] Querying Knowledge Base: {query[:60]}...")
        docs = self.retriever.invoke(query)
        
        context = ""
        sources = set()

        for i, doc in enumerate(docs):
            context += f"\n--- Source {i+1} ---\n{doc.page_content}\n"
            sources.add(doc.metadata.get("source", "unknown"))

        return context, sources

# ---------------- BUILDER LOGIC (FOR SCRIPT RUN) ----------------

def load_documents():
    urls = [
        "https://extension.umn.edu/plant-diseases/apple-scab",
        "https://extension.umn.edu/plant-diseases/black-rot-apple",
        "https://extension.umn.edu/plant-diseases/cedar-apple-rust",
        "https://cals.cornell.edu/school-integrative-plant-science/extension-outreach/apple-scab",
        "https://www.apsnet.org/edcenter/disandpath/ascomycete/pdlessons/Pages/AppleScab.aspx",
        "https://ohioline.osu.edu/factsheet/plpath-fru-01",
        "https://extension.psu.edu/apple-disease-black-rot",
        "https://content.ces.ncsu.edu/black-rot-of-apple",
        "https://www.canr.msu.edu/news/managing_black_rot_in_apples",
        "https://hgic.clemson.edu/factsheet/cedar-apple-rust/",
        "https://hortnews.extension.iastate.edu/cedar-apple-rust",
        "https://extension.okstate.edu/fact-sheets/cedar-apple-rust.html",
        "https://treefruit.wsu.edu/crop-protection/disease-management/",
        "https://attra.ncat.org/publication/apple-diseases-id-sheet/"
    ]

    documents = []
    header = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebkit/537.36"}

    print(f"[INFO] Loading documents...")
    for url in urls:
        try:
            loader = WebBaseLoader(url, header_template=header)
            docs = loader.load()
            for doc in docs:
                doc.page_content = doc.page_content.replace("\n\n", " ").strip()
                doc.page_content = doc.page_content[:8000]
            documents.extend(docs)
        except Exception as e:
            print(f"[ERROR] Failed to load {url}: {e}")

    return documents

def build_index():
    docs = load_documents()
    if not docs:
        print("[ERROR] No docs loaded.")
        return
    
    splitter = RecursiveCharacterTextSplitter(chunk_size=CHUNK_SIZE, chunk_overlap=CHUNK_OVERLAP)
    chunks = splitter.split_documents(docs)
    
    embeddings = HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")
    vectorstore = FAISS.from_documents(chunks, embeddings)
    
    os.makedirs(os.path.dirname(FAISS_PATH), exist_ok=True)
    vectorstore.save_local(FAISS_PATH)
    print(f"[SUCCESS] Index saved to {FAISS_PATH}")

if __name__ == "__main__":
    build_index()
    # Test
    retriever = DiagnosticRetriever()
    context, sources = retriever.get_context("Identify symptoms of Apple Scab")
    print(context[:500])