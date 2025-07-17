from pymilvus import connections, utility

MILVUS_HOST = "192.168.0.10"
MILVUS_PORT = "19530"

print(f"Connecting to Milvus at {MILVUS_HOST}:{MILVUS_PORT}...")
connections.connect(host=MILVUS_HOST, port=MILVUS_PORT)

print("Connected.")
print("Server version:", utility.get_server_version())
print("Collections:", utility.list_collections())

connections.disconnect()
print("Disconnected.") 