podman build --no-cache --rm -f Containerfile -t phoenix:demo .
podman run --interactive --tty -p 4000:4000 phoenix:demo
echo "browse http://localhost:4000/"
