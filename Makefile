.SUFFIXES:

wat2wasm = /home/binji/dev/wasm/wabt/bin/wat2wasm

.PHONY: all
all: docs/index.html docs/metaball.wasm

metaball.wasm: metaball.wat
	$(wat2wasm) -o $@ $<

docs/metaball.wasm: metaball.wasm
	cp $< $@

docs/index.html: metaball.html
	cp $< $@
