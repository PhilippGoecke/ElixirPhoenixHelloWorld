docker build --no-cache --rm -f Containerfile -t phoenix:demo .
docker run --interactive --tty -p 4000:4000 phoenix:demo
