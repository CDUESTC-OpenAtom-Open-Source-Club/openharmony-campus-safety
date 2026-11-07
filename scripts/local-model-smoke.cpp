// Device-only public-fixture smoke check; never reads real account data.
#include "llm/llm.hpp"
#include <chrono>
#include <iostream>
#include <memory>
#include <sstream>
int main(int argc, char** argv) {
    if (argc < 2) return 2;
    auto start = std::chrono::steady_clock::now();
    std::unique_ptr<MNN::Transformer::Llm> llm(MNN::Transformer::Llm::createLLM(argv[1]));
    if (!llm || !llm->load()) return 3;
    const auto loaded = std::chrono::steady_clock::now();
    std::string text = "<|im_start|>system\n你是校安通的小安，用一句简短中文回答。<|im_end|>\n<|im_start|>user\n离开宿舍前应该检查什么？<|im_end|>\n<|im_start|>assistant\n";
    if (argc >= 3) { std::ifstream file(argv[2]); std::ostringstream contents; contents << file.rdbuf(); text = contents.str(); }
    auto prompt = llm->tokenizer_encode(text);
    std::ostringstream output;
    llm->response(prompt, &output, "", 0);
    for (int i = 0; i < (argc >= 4 ? std::stoi(argv[3]) : 80) && !llm->stoped(); ++i) llm->generate(1);
    std::cout << "ANSWER=" << llm->getContext()->generate_str << "\n";
    std::cout << "ELAPSED_MS=" << std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-start).count() << "\n";
    std::cout << "LOAD_MS=" << std::chrono::duration_cast<std::chrono::milliseconds>(loaded-start).count()
              << " PREFILL_US=" << llm->getContext()->prefill_us << " DECODE_US=" << llm->getContext()->decode_us << "\n";
    llm->reset();
    return 0;
}
