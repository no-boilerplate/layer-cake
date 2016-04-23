
build:
	docker build -t layer-cake .

bash:
	docker run 	\
		-it --rm -v $(shell pwd)/.:/app -P 	\
		layer-cake	\
		/bin/bash
