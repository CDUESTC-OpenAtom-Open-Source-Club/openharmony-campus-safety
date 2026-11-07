#include <napi/native_api.h>
#include <chrono>
#include <memory>
#include <mutex>
#include <string>
#include "llm/llm.hpp"

namespace {
using MNN::Transformer::Llm;
std::mutex engineMutex;
std::unique_ptr<Llm> engine;
std::string loadedPath;
struct Job {
    napi_async_work work{};
    napi_deferred deferred{};
    std::string path, prompt, answer, error;
    int limit = 160;
};
bool ReadString(napi_env env, napi_value value, std::string& result, size_t max) {
    size_t length = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &length) != napi_ok || length > max) return false;
    result.resize(length + 1);
    if (napi_get_value_string_utf8(env, value, result.data(), result.size(), &length) != napi_ok) return false;
    result.resize(length);
    return result.find('\0') == std::string::npos;
}
void Execute(napi_env, void* data) {
    auto& job = *static_cast<Job*>(data);
    std::unique_lock<std::mutex> lock(engineMutex, std::try_to_lock);
    if (!lock.owns_lock()) { job.error = "小安正在处理另一条问题"; return; }
    try {
        if (!engine || loadedPath != job.path) {
            engine.reset(Llm::createLLM(job.path));
            if (!engine || !engine->load()) {
                engine.reset(); job.error = "小安模型加载失败"; return;
            }
            loadedPath = job.path;
        }
        engine->reset(); // No cross-question or cross-account KV cache.
        auto tokens = engine->tokenizer_encode(job.prompt);
        if (tokens.empty() || tokens.size() > 4096) { job.error = "问题与应用资料过长，请缩小范围"; return; }
        const auto start = std::chrono::steady_clock::now();
        std::ostringstream output;
        engine->response(tokens, &output, "", 0);
        for (int count = 0; count < job.limit && !engine->stoped(); ++count) {
            if (std::chrono::steady_clock::now() - start > std::chrono::seconds(45)) {
                job.error = "小安处理超时，请缩短问题后重试"; break;
            }
            engine->generate(1);
        }
        if (job.error.empty()) job.answer = engine->getContext()->generate_str;
        if (job.answer.size() > 16000) { job.answer.clear(); job.error = "模型输出过长"; }
        engine->reset();
    } catch (...) {
        engine.reset(); loadedPath.clear(); job.error = "小安模型运行失败";
    }
}
void Complete(napi_env env, napi_status status, void* data) {
    std::unique_ptr<Job> job(static_cast<Job*>(data));
    napi_value result;
    if (status != napi_ok || !job->error.empty()) {
        napi_value message;
        napi_create_string_utf8(env, job->error.empty() ? "模型任务已取消" : job->error.c_str(), NAPI_AUTO_LENGTH, &message);
        napi_create_error(env, nullptr, message, &result);
        napi_reject_deferred(env, job->deferred, result);
    } else {
        napi_create_string_utf8(env, job->answer.c_str(), job->answer.size(), &result);
        napi_resolve_deferred(env, job->deferred, result);
    }
    napi_delete_async_work(env, job->work);
}
napi_value Generate(napi_env env, napi_callback_info info) {
    napi_value args[3]; size_t count = 3;
    napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    auto job = std::make_unique<Job>();
    if (count != 3 || !ReadString(env, args[0], job->path, 2048) ||
        !ReadString(env, args[1], job->prompt, 24000) ||
        napi_get_value_int32(env, args[2], &job->limit) != napi_ok || job->limit < 1 || job->limit > 192 ||
        job->path.find("/xiaoan-qwen3-06/config.json") == std::string::npos || job->path.find("..") != std::string::npos) {
        napi_throw_type_error(env, nullptr, "Invalid local model request"); return nullptr;
    }
    napi_value promise, name;
    napi_create_promise(env, &job->deferred, &promise);
    napi_create_string_utf8(env, "XiaoAnInference", NAPI_AUTO_LENGTH, &name);
    if (napi_create_async_work(env, nullptr, name, Execute, Complete, job.get(), &job->work) != napi_ok ||
        napi_queue_async_work(env, job->work) != napi_ok) {
        napi_throw_error(env, nullptr, "Cannot queue local inference"); return nullptr;
    }
    job.release(); return promise;
}
napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor descriptor = { "generate", nullptr, Generate, nullptr, nullptr, nullptr, napi_default, nullptr };
    napi_define_properties(env, exports, 1, &descriptor);
    return exports;
}
napi_module module = {1, 0, nullptr, Init, "xiaoan", nullptr, {0}};
}
extern "C" __attribute__((constructor)) void RegisterXiaoAnModule() { napi_module_register(&module); }
