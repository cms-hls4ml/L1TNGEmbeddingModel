#!/bin/bash
# Wraps da4ml-generated ctl2_embedding sources for CMSSW hls4mlEmulator
# Usage: ./setup.sh <version> [source_dir]
#   e.g. ./setup.sh v0 ../hls_da4ml/src
set -euo pipefail

VERSION=${1:-v0}
MODEL_NAME=ctl2_embedding
FQN=${MODEL_NAME}_${VERSION}
NS=hls4ml_${FQN}
TARGET=${FQN}/NN
SRC_DIR=${2:-../hls_da4ml/src}

mkdir -p ${TARGET}

# ── Copy the firmware (the single self-contained header) ──
cp ${SRC_DIR}/${MODEL_NAME}.hh  ${TARGET}/${MODEL_NAME}.hh

# ── Namespace-wrap: comb_logic → hls4ml_ctl2_embedding_<ver> ──
sed -i "s/namespace comb_logic/namespace ${NS}/g"  ${TARGET}/${MODEL_NAME}.hh

# ── Emulator .cpp ──
# da4ml's top-level is a header-only template; the emulator instantiates it.
# The template is NOT compiled to a separate object — it gets instantiated
# inside the emulator .cpp when predict() calls it.
cat > ${FQN}/${MODEL_NAME}_emulator_${VERSION}.cpp << CPP
#include "NN/${MODEL_NAME}.hh"
#include "emulator.h"
#include "ap_fixed.h"
#include <any>
#include <cstddef>

using input_t  = ap_fixed<11, 3>;
using output_t = ap_fixed<23, 4>;

static constexpr unsigned N_INP = 1200;
static constexpr unsigned N_OUT = 20;

struct ModelInputs {
    input_t* data;
};

struct ModelOutputs {
    output_t* data;
};

class ${MODEL_NAME}_emulator_${VERSION} : public hls4mlEmulator::Model {
private:
    input_t  _inp[N_INP];
    output_t _out[N_OUT];

public:
    virtual void prepare_input(std::any input) override {
        auto in = std::any_cast<ModelInputs>(input);
        for (unsigned i = 0; i < N_INP; ++i)
            _inp[i] = in.data[i];
    }

    virtual void predict() override {
        ${NS}::${MODEL_NAME}<input_t, output_t>(_inp, _out);
    }

    virtual void read_result(std::any result) override {
        auto* out = std::any_cast<ModelOutputs*>(result);
        for (unsigned i = 0; i < N_OUT; ++i)
            out->data[i] = _out[i];
    }
};

extern "C" hls4mlEmulator::Model* create_model() {
    return new ${MODEL_NAME}_emulator_${VERSION};
}

extern "C" void destroy_model(hls4mlEmulator::Model* m) {
    delete m;
}
CPP

# ── Per-version Makefile ──
# da4ml header is a template — instantiated inside the emulator, so only one .o.
# The produced binary is always L1TEmbeddingModel.so (what the CMSSW producer
# loads via the hls4ml emulator interface).
cat > ${FQN}/Makefile << MK
.PHONY: clean

L1TEmbeddingModel.so: ${MODEL_NAME}_emulator_${VERSION}.o
	\$(CXX) \$(CXXFLAGS) \$(LD_FLAGS) -shared \$^ -o \$@

%.o: %.cpp
	\$(CXX) \$(CXXFLAGS) \$(INCLUDES) -c \$< -o \$@

clean:
	rm -f ${MODEL_NAME}_emulator_${VERSION}.o L1TEmbeddingModel.so
MK

echo "Done: ${FQN}/"
echo "  Firmware:   ${TARGET}/${MODEL_NAME}.hh  (namespace ${NS})"
echo "  Emulator:   ${FQN}/${MODEL_NAME}_emulator_${VERSION}.cpp"
echo "  Per-ver Makefile: ${FQN}/Makefile"