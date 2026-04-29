.PHONY: demo clean format lint test

PLUGIN_PATH := $(shell pwd)

format:
	stylua .

lint:
	luacheck lua/

test:
	nvim --headless -u NONE -c "lua dofile('tests/run.lua')" -c qa

demo:
	@echo "Recording demo.gif..."
	PLUGIN_PATH=$(PLUGIN_PATH) vhs docs/demo.tape
	@echo "Done! Output: docs/demo.gif"

clean:
	rm -rf /tmp/vhs-glaze-config /tmp/vhs-glaze-data /tmp/glaze-demo
