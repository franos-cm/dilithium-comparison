# Overview

This project briefly compares two designs that completely implement the CRYSTALS-Dilithium [1] algorithm on RTL. Some limitations of each design are mentioned, along with quantitative performance measurements.

# 1. Introduction

Although a plethora of work exists detailing different hardware-accelerated implementations of Dilithium, the source code for them are tipically not found online. The only exceptions found are the two projects presented here: *A Hard Crystal - Implementing Dilithium on Reconfigurable Hardware* [2], and *High-Performance Hardware Implementation of CRYSTALS-Dilithium* [3]. These works follow somewhat different strategies in implementing Dilithium, makint it interesting to compare them, not only in terms of latency and resource usage, but also from a qualitative perspective.

For reasons that will become apparent later, we have decided to call the implementation in [2] "LowRes" (*Low Resource Usage*), and the implementation in [3] "HighPerf" (*High Performance*), in order to differentiate them. We also refer to the three main Dilithium operations as `KEYGEN`, `SIGN`, and `VERIFY`.

**Surprisingly, both designs originally had bugs which either produced incorrect output values, or limited their practical usability in real-world scenarios.** Notably, in the case of HighPerf, a small but critical bug related to the NTT module was discovered and detailed in [5] (Section 3.B.1). Although relatively easy to fix, the time-constrained nature of this project means that **the original module has (so far) been left unchanged**, since the bug is not expected to impact either latency or resource usage significantly. 

> ℹ️ **Note:**  
> It should be noted that there is also a third hardware-accelerated implementation of Dilithium in *Optimized Hardware-Software Co-Design for Kyber and Dilithium on RISC-V SoC FPGA* [4].
> 
> However, this alternative follows a hybrid hardware-software approach, in which only some operations are accelerated in hardware, and the others are performed by four ARM hard cores.
>
> Therefore, this third implementation not only differs significantly from the others, but it is also not as easily simulated using the typical Vivado workflow.

# 2. Key design points

## 2.1. Modularity

The two cores are designed with different degrees of modularity.

Especifically, LowRes is composed of three base designs — each capable of performing one of Dilithium's three main operations — and one additional design that essentially integrates the other three to provide a complete suite for the algorithm.

This modular structure allows for projects which only need to perform one of the operations (for example, a system that is only interested in validating signatures), to reduce its resource usage.

Each design itself also comes in three variants, one for each security level specified for Dilithium. This means that, although the difference between these variants are essentially that of internal buffer sizes, there is currently no option to select the security level at runtime.

HighPerf, on the other hand, is a single unified design capable of performing all three Dilithium operations. Moreover, the security level for a given operation can be decided at runtime by use of the ```sec_level``` input signal.

## 2.2. Interfaces

Considering the data throughput necessary for the operations in Dilithium, both cores are designed with a streaming interface similar to that of AXI-Stream [6], coupled with a side-band for certain control signals, such as ```start```, or ```sec_level``` (in the case of HighPerf).

One of the main differences between the two designs is that HighPerf has a 64-bit datapath, while LowRes uses a 32-bit one. This alone effectively doubles the latency of load and store operations in LowRes, when compared to HighPerf.

Furthermore, **both designs originally had bugs related to the handshaking protocol used for this interface**. In the case of LowRes, this issue was resolved simply by changing some internal signal definitions.

For HighPerf, the most straightforward solution was to introduce a buffer that captures the core's output and retransmits it to the streaming interface, correctly following the protocol. This, in turn, increases the amount of resources required by the design. Although there are certainly more efficient solutions which require changing the core's FSMs, it should be noted that this additional buffer represents less than 3% of the total memory needed by the original design.

## 2.3. Pipelining and data reusability

The two cores have different ways of mitigating the latency for the Dilithium operations. Notably, HighPerf has a highly pipelined design structure that allows for simultaneously executing independent steps (reading the original paper is recommended for more details).

LowRes's design implements significantly less pipelining. However, while HighPerf's design is based on streaming all the data necessary for each Dilithium operation, LowRes allows for performing intermediate loading and storing operations separately from the main processing steps. This then allows for reusing data across different operations, which reduces data transfer times.

For example, suppose we wanted to compute several signatures using the same secret key, HighPerf requires loading the key for every signature, while LowRes would only load the key when performing the first signature, and reuse that value for the subsequent ones.



## 2.4. Keccak

Dilithium's operations internally use a collision resistant hash function, both for hashing and also for pseudo-random number generation. The CRHF used is specified to be SHAKE256 for hashing, and SHAKE128 for PRNG (specifically, when expanding the matrix `A`).

As such, both designs include an implementation of a core that performs the Keccak family of functions [7]. This is somewhat important since the SHAKE operations are typically one of the bottlenecks for the Dilithium algorithm as a whole.

Both designs execute a Keccak round in one cycle, and therefore finish the Keccak-f[1600] permutation in 24 cycles. Similarly, in both cases the Keccak state is implemented as a single 1600 bit register, with different values for ```(c, r)``` depending on which SHAKE operation is being performed.

LowRes's Keccak core has a very simple design, in which the state buffer is directly accessed after each permutation, both to load the next input block, and similarly to dump the next output block.

HighPerf reduces the latency for these load and dump operations by pipelining the Keccak core design into three stages, as well as introducing one input buffer and one output buffer. As a result, the Keccak permutation can be executed while the next input block is being independently loaded, and the previous output block is being dumped.

Moreover, to maximize throughput even further, HighPerf instantiates three copies of its Keccak core, compared to the single Keccak core used in LowRes.

However, **HighPerf's implementation of Keccak has one major limitation**. As specified in its documentation [8], the input and output sizes are determined by the first 64-bit word received by the core. For this reason, its input size is limited to the [0, 2³²] bits range, and its output size is limited to the [0, 2²⁸] bits range. The output size range is not relevant for Dilithium, given that all SHAKE operations need to produce a much lower amount of data than the upper bound specified. The input size range, however, means that **HighPerf's Dilithium core can only sign messages with at most 4GB of data**.

This limitation can be easily fixed by having the interface include a signal similar to AXI-Stream's ```TLAST```, whose purpose LowRes mimics by overloading the ```TREADY``` signal asserted by the transmitter device. As such, LowRes has no similar message size limit. I eventually plan on including this change in [my own version of a high-performance Keccak core](https://github.com/franos-cm/shake-sv), which is heavily inspired by [8].


## 2.5. Test suite

In order to produce comparable latency metrics, a unified testbench environment was developed to simulate the designs. This setup is based on HighPerf's original testbench; LowRes, unfortunately, provides no testbench with its source code, and makes no mention of a testing suite in its original paper.

Before the testbench could be implemented, we first had to standardize the interface for the two modules. As previously mentioned, the streaming interface for both cores are essentially the same, albeit with different data widths. Therefore, we only needed to modify the side-band used for the control signals. Thus, we developed an adapter module specific for each core.

The Known Answer Test (KAT) vectors from CRYSTALS own reference implementation of Dilithium [9] were used as the input and output vectors for the testbench.

Finally, as previously mentioned, since LowRes allows for separating load and store operations from the main computation step, it is useful to similarly consider these steps separately when measuring latency. On the other hand, given HighPerf's pipelined and parallel design, there is no clear separation between these steps, and only the total latency is reported.


# 3. Results

The first table below shows the latency metrics obtained by a behavioural simulation of both designs, using the unified testbench.

[Table1]

The second table shows the resource usage for both designs, as synthethized by Vivado 2024.2 for different Xilinx boards.

[Table2]

# Conclusion

# References

1. [CRYSTALS-Dilithium](https://pq-crystals.org/dilithium/index.shtml)

2. [A Hard Crystal - Implementing Dilithium on Reconfigurable Hardware](https://github.com/Chair-for-Security-Engineering/dilithium-artix7)

3. [High-Performance Hardware Implementation of CRYSTALS-Dilithium](https://github.com/GMUCERG/Dilithium)

4. [Optimized Hardware-Software Co-Design for Kyber and Dilithium on RISC-V SoC FPGA](https://github.com/Acccrypto/RISC-V-SoC)

5. [Efficient Implementation of Dilithium Signature Scheme on FPGA SoC Platform](https://ieeexplore.ieee.org/document/9810520)

6. [AMBA® AXI-Stream Protocol Specification](https://documentation-service.arm.com/static/64819f1516f0f201aa6b963c)
   
7. [The Keccak reference](https://keccak.team/files/Keccak-reference-3.0.pdf)

8. [CERG SHA3 Core Documentation](https://github.com/GMUCERG/SHAKE)

9. [CRYSTALS-Dilithium NIST submission package for round 3](https://pq-crystals.org/dilithium/data/dilithium-submission-nist-round3.zip)