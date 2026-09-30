#include "NN/ctl2_embedding.hh" // include of the top level of the HLS model
#include "emulator.h"           // include of the emulator modeling
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

class ctl2_embedding_emulator_v0 : public hls4mlEmulator::Model {
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
        hls4ml_ctl2_embedding_v0::ctl2_embedding<input_t, output_t>(_inp, _out);
    }

    virtual void read_result(std::any result) override {
        auto* out = std::any_cast<ModelOutputs*>(result);
        for (unsigned i = 0; i < N_OUT; ++i)
            out->data[i] = _out[i];
    }
};

extern "C" hls4mlEmulator::Model* create_model() {
    return new ctl2_embedding_emulator_v0;
}

extern "C" void destroy_model(hls4mlEmulator::Model* m) {
    delete m;
}