podman build --no-cache --rm --file=Containerfile.LiveView --tag phoenix:liveview .
podman run --interactive --tty --name=phoenix.liveview --replace --publish 4004:4004 phoenix:liveview
echo "browse https://localhost:4004/tasks"
