.PHONY: demo clean

PLUGIN_PATH := $(shell pwd)

demo:
	@echo "Recording demo.gif..."
	PLUGIN_PATH=$(PLUGIN_PATH) vhs docs/demo.tape
	@echo "Done! Output: docs/demo.gif"

clean:
	rm -rf /tmp/vhs-glaze-config /tmp/vhs-glaze-data /tmp/glaze-demo
