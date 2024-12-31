import torch

def check_cuda():
    if torch.cuda.is_available():
        num_gpus = torch.cuda.device_count()
        print(f"CUDA is available! Number of GPUs: {num_gpus}")

        for i in range(num_gpus):
            print(f"\nGPU {i} details:")
            print(f"  Name: {torch.cuda.get_device_name(i)}")
            print(f"  Compute Capability: {torch.cuda.get_device_capability(i)}")
            print(f"  Total Memory: {torch.cuda.get_device_properties(i).total_memory / (1024 ** 3):.2f} GB")
            print(f"  Multiprocessors: {torch.cuda.get_device_properties(i).multi_processor_count}")
    else:
        print("CUDA is not available on this system.")

if __name__ == "__main__":
    check_cuda()
