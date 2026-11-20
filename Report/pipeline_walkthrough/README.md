# Pipeline walkthrough

Interactive page: pick an instruction to see the wires it uses in each stage of the
draw.io schematic, or replay a test program cycle by cycle (data from the VHDL simulation),
with the F / D / E1 / E2 / M / W pipeline chart underneath.

Open it with a local web server (the page loads `data.json` and `schema.png`):

    cd Report/pipeline_walkthrough
    python -m http.server 8000
    # then browse to http://localhost:8000/index.html

`gen_sim.py` rebuilds `data.json` from the schematic generator and the simulation traces.
