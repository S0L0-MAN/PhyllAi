import os

# 1. FIX: Set User Agent before any LangChain imports to avoid blocking
os.environ["USER_AGENT"] = "CropDiseaseResearchBot/1.0"

from langchain_community.document_loaders import WebBaseLoader, TextLoader
try:
    # Modern LangChain structure
    from langchain_text_splitters import RecursiveCharacterTextSplitter
except ImportError:
    # Fallback for older versions
    from langchain.text_splitter import RecursiveCharacterTextSplitter

from langchain_huggingface import HuggingFaceEmbeddings
from langchain_community.vectorstores import FAISS

# ---------------- CONFIG ----------------
FAISS_PATH = "faiss_index_apple"
CHUNK_SIZE = 600
CHUNK_OVERLAP = 120
TOP_K = 5

# ---------------- LOAD DOCUMENTS ----------------
def load_documents():
    # 25+ Specific Sources for Apple Scab, Black Rot, and Cedar Rust
    urls = [
        # Apple Scab
        "https://extension.umn.edu/plant-diseases/apple-scab",
        "https://cals.cornell.edu/school-integrative-plant-science/extension-outreach/apple-scab",
        "https://www.apsnet.org/edcenter/disandpath/ascomycete/pdlessons/Pages/AppleScab.aspx",
        "https://ohioline.osu.edu/factsheet/plpath-fru-01",
        "https://extension.usu.edu/pests/uppl/files/factsheet/apple-scab.pdf",
        "https://extension.unh.edu/resource/apple-scab-fact-sheet",
        "https://ag.umass.edu/fruit/fact-sheets/apple-scab",
        
        # Black Rot
        "https://extension.umn.edu/plant-diseases/black-rot-apple",
        "https://extension.psu.edu/apple-disease-black-rot",
        "https://content.ces.ncsu.edu/black-rot-of-apple",
        "https://www.canr.msu.edu/news/managing_black_rot_in_apples",
        "https://plantpathology.ca.uky.edu/files/ppfs-fr-t-02.pdf",
        "https://ag.umass.edu/fruit/fact-sheets/apple-black-rot",
        "https://extension.wvu.edu/lawn-gardening-pests/plant-disease/fruit-diseases/black-rot-of-apple",

        # Cedar Apple Rust
        "https://extension.umn.edu/plant-diseases/cedar-apple-rust",
        "https://hgic.clemson.edu/factsheet/cedar-apple-rust/",
        "https://hortnews.extension.iastate.edu/cedar-apple-rust",
        "https://extension.okstate.edu/fact-sheets/cedar-apple-rust.html",
        "https://www.missouribotanicalgarden.org/gardens-gardening/your-garden/help-for-the-gardener/advice-tips-resources/pests-and-problems/diseases/rusts/cedar-apple-rust.aspx",
        "https://agnet.tamu.edu/2022/05/20/cedar-apple-rust/",
        "https://extension.unl.edu/publications/g1907.pdf",

        # General/Multi-Disease Indexes
        "https://treefruit.wsu.edu/crop-protection/disease-management/",
        "https://attra.ncat.org/publication/apple-diseases-id-sheet/",
        "https://extension.umaine.edu/fruit/growing-fruit-trees-in-maine/diseases/",
        "https://extension.missouri.edu/publications/g6026",
        "https://extension.tennessee.edu/publications/Documents/W330.pdf"
    ]

    documents = []
    print(f"[INFO] Loading {len(urls)} web documents...")
    
    for url in urls:
        try:
            loader = WebBaseLoader(url)
            docs = loader.load()

            for doc in docs:
                # Basic cleaning to remove excessive whitespace
                doc.page_content = " ".join(doc.page_content.split())
                doc.page_content = doc.page_content[:8000]

            documents.extend(docs)
            print(f"[SUCCESS] Loaded: {url}")
        except Exception as e:
            print(f"[WARNING] Failed to load {url}: {e}")

    # Load local file if exists
    if os.path.exists("local_agri_notes.txt"):
        try:
            loader = TextLoader("local_agri_notes.txt")
            documents.extend(loader.load())
            print("[INFO] Local agri notes loaded.")
        except Exception as e:
            print(f"[ERROR] Could not load local file: {e}")
    
    return documents

# ---------------- CHUNKING ----------------
def chunk_documents(documents):
    print("[INFO] Chunking documents...")
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=CHUNK_SIZE,
        chunk_overlap=CHUNK_OVERLAP,
        separators=["\n\n", "\n", ". ", " "]
    )
    chunks = splitter.split_documents(documents)
    print(f"[INFO] Total chunks created: {len(chunks)}")
    return chunks

# ---------------- EMBEDDINGS ----------------
def get_embeddings():
    print("[INFO] Loading embedding model...")
    return HuggingFaceEmbeddings(model_name="sentence-transformers/all-MiniLM-L6-v2")

# ---------------- VECTOR STORE ----------------
def build_or_load_vectorstore(chunks, embeddings):
    # Check if folder exists and has files in it
    if os.path.exists(FAISS_PATH) and len(os.listdir(FAISS_PATH)) > 0:
        print("[INFO] Loading existing FAISS index...")
        return FAISS.load_local(FAISS_PATH, embeddings, allow_dangerous_deserialization=True)
    else:
        print("[INFO] Creating new FAISS index...")
        vectorstore = FAISS.from_documents(chunks, embeddings)
        vectorstore.save_local(FAISS_PATH)
        return vectorstore

# ---------------- RETRIEVER ----------------
def get_retriever(vectorstore):
    return vectorstore.as_retriever(
        search_type="similarity",
        search_kwargs={"k": TOP_K}
    )

# ---------------- QUERY ----------------
def retrieve_context(retriever, query):
    print(f"[INFO] Retrieving context for query: {query[:60]}...")
    docs = retriever.invoke(query) # Modern replacement for get_relevant_documents
    
    context = ""
    sources = set()

    for i, doc in enumerate(docs):
        context += f"\n--- Source {i+1} ---\n{doc.page_content}\n"
        sources.add(doc.metadata.get("source", "unknown"))

    return context, sources

# ---------------- MAIN ----------------
if __name__ == "__main__":
    # Execute Pipeline
    raw_docs = load_documents()
    
    if not raw_docs:
        print("[ERROR] Pipeline stopped: No documents were successfully loaded.")
    else:
        doc_chunks = chunk_documents(raw_docs)
        embed_model = get_embeddings()
        vector_store = build_or_load_vectorstore(doc_chunks, embed_model)
        retriever = get_retriever(vector_store)

        # Example Test Query
        test_query = "What are the characteristics of Cedar Apple Rust on apple leaves?"
        context, sources = retrieve_context(retriever, test_query)

        print("\n" + "="*30 + " RETRIEVED DATA " + "="*30)
        print(context[:1500] + "...") 
        
        print("\n" + "="*30 + " SOURCES CONSULTED " + "="*30)
        for s in sources:
            print(f"- {s}")