# 校安通 · 小安的第三方组件

- Qwen3-0.6B：Qwen / Alibaba Cloud，Apache License 2.0，见 LICENSE-Qwen.txt。
- taobao-mnn/Qwen3-0.6B-MNN：MNN 官方量化导出，Apache License 2.0。模型版本与文件 SHA-256 固定在模型准备脚本中。
- MNN 3.4.1：Alibaba Group，Apache License 2.0，见 LICENSE-MNN.txt。使用的源码提交为 6b1db4c2eacf8193e6b7a1841acb6e31a1938e82。
- MNN 内包含的 RapidJSON、half、FlatBuffers，以及来自 TensorFlow、Skia 的部分代码：保留对应 LICENSE 文件。

对 MNN 的修改：`scripts/mnn-legacy-tied-embedding.patch` 增加可选 `embedding_alpha_is_min` 配置，使旧导出中已经存为最小值的量化 alpha 不再被二次偏移。默认关闭，不改变其他模型的原有行为。此兼容开关供旧格式导出使用，当前 Qwen3-0.6B 不启用它。当前模型使用上游自带的 tied embeddings；三份模型二进制文件未修改。

上游地址：https://github.com/alibaba/MNN 、https://huggingface.co/Qwen/Qwen3-0.6B 、https://huggingface.co/taobao-mnn/Qwen3-0.6B-MNN 。上述权利人不为本项目的修改或回答质量作保证。
