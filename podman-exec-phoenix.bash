podman exec --interactive --tty $(podman ps -q --filter=status=running --filter name=phoenix) bash
