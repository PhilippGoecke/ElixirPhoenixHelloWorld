podman build --no-cache --rm --file=Containerfile.LiveView --tag phoenix:liveview .
podman run --interactive --tty --name=phoenix --replace --publish 4003:4003 --publish 4004:4004 phoenix:liveview
echo "browse http://localhost:4003/tasks or https://localhost:4004/tasks"
