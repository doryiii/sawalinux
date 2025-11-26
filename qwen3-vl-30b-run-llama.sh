LLAMA_CACHE=/mnt/models/models/llama.cpp-cache llama-server \
    --model qwen3-vl-30b-thinking-q4_k_m.gguf --alias qwen3-vl-30b \
    --mmproj qwen3-vl-30b-thinking-mmproj.gguf \
    --ctx-size 40000 --cache-type-k q8_0 --cache-type-v q8_0 \
    --override-tensor '\.[2-9][0-9]\.ffn_(up|down)_exps.=CPU' \
    --jinja \
    --flash-attn on \
    --n-gpu-layers 99 --device Vulkan0 \
    --parallel 1 --threads 64 \
    --host 0.0.0.0 --port 8090

