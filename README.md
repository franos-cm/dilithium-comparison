# Overview

This project briefly compares two designs that completely implement the CRYSTALS-Dilithium algorithm on RTL logic AAAAA. Some trade-offs and limitations of each design are mentioned, along with quantitative performance measurements AAAAA.

# 1. Introduction

Although a plethora of work exists detailing different hardware-accelerated implementations of Dilithium, the source code for them are tipically not found online. The only exceptions found are the two projects presented here: AAAA and AAAA. These works follow somewhat different strategies in implementing Dilithium, and therefore it is interesting to compare them, both in terms of latency and of resources used.
AAAAA quantitatively (i.e. latency and of resources used), and qualitatively.

For reasons that will become apparent later, we have decided to call the implementation in [1] "HighPerf" (which stands AAAAA for High Performance), and the implementation in [2] as "LowRes" (which stands for Low Resource Usage), in order to differentiate them. (We also refer to the three main Dilithium operations as ```KEYGEN```, ```SIGN```, and ```VERIFY```.)

Surprisingly, both designs originally had bugs which either produced incorrect output values, or reduced its practical usage in real life AAAAA scenarios. Notably, in the case of HighPerf, a small but critical bug related to the NTT module was discovered and detailed by [AAA] (Section AAA). Although relatively easy to fix, the expedient AAA nature of this project means that we left the original module as is, since the bug is not expected to impact either latency or resource usage significantly. 

> NOTE
> 
> It should be noted that there is also a third hardware-accelerated implementation of Dilithium whose source code is made available in AAAA.
> 
> However, this alternative follows a hybrid hardware-software approach, in which only some operations are accelerated in hardware, and the others are performed by four ARM hard cores.
>
> As such, this third implementation is not only MORE DIFFERENT TO THE OTHERS AAAAAA, but it is also not as easily simulated using the typical Vivado workflow.

# 2. Key design points

## 2.1. Modularity

The two cores are designed with different degrees of modularity.

Especifically, LowRes is composed of three base designs --- each capable of performing one of Dilithium's three main operations --- and one additional design that essentially concatenates AAAAAAAA the other three to provide a complete suite for the algorithm.

This separation AAAAA allows for projects which only need to perform one of the operations (for example, a system that is only interested in validating signatures), to reduce its resource usage.

Each design itself also has three different variants, one for each security level specified for Dilithium. That means that, although the difference between these variants are essentially that of internal buffer sizes, as it stands there is no option for deciding the security level during runtime.

HighPerf, on the other hand, is a single unified design capable of performing all three Dilithium operations. Moreover, the security level for a given operation can be decided during runtime by use of the ```sec_level``` input signal.

As for the control interfaces, the two cores implement different signals with different meanings. HighPerf has the aforementioned ```sec_level``` signal for determining the security level of the operation, and the ```mode``` signal for determining which of the three Dilithium

## 2.2. Interfaces

Considering the data throughput necessary for the operations in Dilithium, both cores are designed with a streaming interface similar to that of AXI-Stream [3], coupled with a side-band for certain control signals, such as ```start```, or ```sec_level``` (in the case of HighPerf).

One of the main differences between the two designs is that HighPerf has a 64 bit stream data width, while LowRes uses a 32 data width. This alone AAAA at least doubles the latency of load and store operations for LowRes, when compared to HighPerf.

Moreover AAAA, **both designs originally had bugs related to the handshaking protocol for this interface**. In the case of LowRes, the solution was simply changing some internal signal definitions on the design.

For HighPerf, the simplest solution was to introduce a buffer that captures the core's output and retransmits it to the streaming interface, correctly following the protocol. This, in turn, increases the amount of resources required by the design. Although there are certainly more efficient solutions which require changing the core's FSMs, it should be noted that this additional buffer represents less than 3% of the total memory needed AAAAA by the original design.

## 2.3. Pipelining and data reusability

The two cores have different ways of HIDING/AMORTIZING AAAAAA the latency for the Dilithium operations. Notably, HighPerf has a highly pipelined design structure that allows for simultaneously executing independent steps (we recommend reading the original paper for more details).

LowRes' AAAA design implements AAAA much less AAAA pipelining. On the other hand, while HighPerf's design is based on streaming all the data necessary for each Dilithium operation, LowRes allows for performing intermediate loading and storing operations separately from the main AAAA computation. This then allows for reusing data between different operations, which reduces data transfer times.

For example, suppose we wanted to perform several signatures using the same secret key, HighPerf requires loading the key for every signature, while LowRes would only load the key when performing the first signature, and reuse that value for the subsequent ones.



## 2.4. Keccak

Dilithium's operations internally use a collision resistant hash function, both for hashing and also for pseudo-random number generation. The CRHF used is specified to be SHAKE128 for some hashes and SHAKE256 for others. As such, both designs include an implementation of a core to perform the Keccak family of functions [4]. This is somewhat important since the SHAKE operations are typically one of the bottlenecks for the Dilithium algorithm as a whole.

Both designs execute a Keccak round in one cycle, and therefore finish the necessary Keccak-f[1600] permutation in 24 cycles. Similarly, in both cases the Keccak state is implemented as a single 1600 bit register, with different values for ```(c, r)``` depending on which SHAKE operation is being performed.

LowRes' AAAAA Keccak core has a very simple design, in which the state buffer is directly accessed to load the next input block, and similarly to dump the next output block, after each permutation.

HighPerf reduces the latency for these load and dump operations by pipelining the design into three stages, and introducing one input buffer and one output buffer. As such, the Keccak permutation can be executed while the next input block is being independently loaded, and the previous output block is being dumped.

Moreover AAAA, to maximize throughput even further, HighPerf instantiates three copies of its Keccak core, as opposed to LowRes' single one AAAAA.

However, **HighPerf's implementation of Keccak has one major limitation**. As specified in its original documentation [5], the input and output sizes are determined in the first 64 word received by the core. As such AAAAA, its input size is limited to the [0, 2^32] range, and its ouput size is limited to the [0, 2^28] range. The output size range is not relevant for Dilithium, given that all SHAKE operations need only to produce AAAAA a much lower amount of data than the upper bound specified. The input size range, however, means that **HighPerf's Dilithium core can only sign up to 4Gb of data**.

This limitation can be easily fixed by having the interface include a signal similar to AXI-Stream's ```T_LAST```, which is similar AAAA to what LowRes does by overloading the ```T_READY``` signal asserted by the master device AAAA to serve this function AAAAA. I eventually plan on including this change in my own version of the Keccak core AAAAAA, which is heavily inspired by HighPerf's.


## 2.5. Test suite

To produce comparable latency metrics, a unified testbench was developed to simulate the designs. The testbench is based on HighPerf's original testbench; LowRes, unfortunately, provides no testbench along with its source code, and mentions no testing suite in its original paper.

In order to do have a unified testbench, we first had to standardize the interface for the two modules. As previously mentioned, the streaming interface for both cores are essentially the same, albeit with different data widths. Therefore, we only needed to modify the side-band used for the control signals. Thus, we developed an adapter module specific for each core.

The Known Answer Test (KAT) vectors from CRYSTALS own reference implementation of Dilithium [AAAA] were used as the input and output vectors for the testbench.

As previously mentioned, since LowRes allows for separating load and store operations from the main algorithm computation AAAA, it is useful to similarly separate between these steps when taking the AAAAA latency metrics. On the other hand, given HighPerf's pipelined and parallel design, there is no clear separation between these steps, and only the total latency is provided.


# 3. Results

The first table below shows the latency metrics obtained by a behavioural simulation of both designs, using the unified testbench.

[Table1]

The second table shows the resource usage for both designs, as synthethized by Vivado 2024.2 for different Xilinx boards.

[Table2]

# Conclusion