.PHONY: clean

L1TEmbeddingModel.so: ctl2_embedding_emulator_v0.o
	$(CXX) $(CXXFLAGS) $(LD_FLAGS) -shared $^ -o $@

%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f ctl2_embedding_emulator_v0.o L1TEmbeddingModel.so