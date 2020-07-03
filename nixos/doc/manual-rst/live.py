from livereload import Server, shell

server = Server()

build_docs = shell("sphinx-build -M html ./source ./build")

print("Doing an initial build of the docs...")
build_docs()

server.watch("source/*.rst", build_docs)
server.watch("source/**/*.rst", build_docs)
server.watch("_templates/*.html", build_docs)
server.serve(root="build/html")
