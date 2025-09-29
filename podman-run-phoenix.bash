podman build --no-cache --rm --file=Containerfile --tag phoenix:demo .
podman run --interactive --tty --name=phoenix --publish 4000:4000 phoenix:demo
echo "browse http://localhost:4000/hello/World"
