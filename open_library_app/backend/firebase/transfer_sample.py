import firebase_admin
from firebase_admin import credentials, firestore

# Initialize the app
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

def extract_schema(collection_name, sample_limit=5):
    docs = db.collection(collection_name).limit(sample_limit).stream()
    schema = {}
    
    for doc in docs:
        data = doc.to_dict()
        for key, value in data.items():
            dtype = type(value).__name__
            schema[key] = dtype
    return schema

# Example: List top-level collections and their field structure
collections = db.collections()

for collection in collections:
    print(f"\n📁 Collection: {collection.id}")
    schema = extract_schema(collection.id)
    for field, dtype in schema.items():
        print(f"  • {field}: {dtype}")
