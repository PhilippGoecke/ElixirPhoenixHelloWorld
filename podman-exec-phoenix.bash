podman exec --interactive --tty $(podman ps --quiet --filter=status=running --filter name=phoenix) bash
