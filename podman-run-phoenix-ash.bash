podman build --no-cache --rm --file=Containerfile.Ash --tag phoenix:ash .
podman run --interactive --tty --name=phoenix --replace --publish 4001:4000 phoenix:ash
echo "browse http://localhost:4001/hello/World"
