podman build --no-cache --rm --file=Containerfile.Bootstrap --tag phoenix:bootstrap .
podman run --interactive --tty --publish 4002:4000 phoenix:bootstrap
echo "browse http://localhost:4002/"
