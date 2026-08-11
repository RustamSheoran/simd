#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>

// Keep this intentionally non-vector-intrinsic: it is the ordinary C++
// baseline compiled with -O3.  Inspect build/dot_benchmark.dis to see what
// the compiler chose for the target CPU.
extern "C" __attribute__((noinline)) std::int64_t cpp_dot_product(
    const std::int32_t* a, const std::int32_t* b, std::size_t count) {
    std::int64_t sum = 0;
    for (std::size_t i = 0; i < count; ++i) {
        sum += static_cast<std::int64_t>(a[i]) * b[i];
    }
    return sum;
}

extern "C" std::int64_t neon_dot_product(
    const std::int32_t* a, const std::int32_t* b, std::size_t count);

namespace {
constexpr std::size_t kCount = 1'000'003; // deliberately leaves a 3-element tail
constexpr int kTrials = 9;
constexpr int kRepeatsPerTrial = 20;

alignas(16) std::int32_t a[kCount];
alignas(16) std::int32_t b[kCount];
volatile std::int64_t benchmark_sink = 0;

using DotFn = std::int64_t (*)(const std::int32_t*, const std::int32_t*, std::size_t);

void initialize_inputs() {
    for (std::size_t i = 0; i < kCount; ++i) {
        // Bounded deterministic values keep the exact total well inside int64_t.
        a[i] = static_cast<std::int32_t>((i * 17 + 3) % 2001) - 1000;
        b[i] = static_cast<std::int32_t>((i * 31 + 7) % 1999) - 999;
    }
}

double benchmark_ns_per_dot(DotFn dot) {
    using Clock = std::chrono::steady_clock;
    long double total_ns = 0;
    DotFn volatile call_target = dot;
    for (int trial = 0; trial < kTrials; ++trial) {
        // The timed interval contains only repeated calls to the dot product.
        const auto start = Clock::now();
        std::int64_t result = 0;
        for (int repeat = 0; repeat < kRepeatsPerTrial; ++repeat) {
            result = call_target(a, b, kCount);
        }
        const auto stop = Clock::now();
        benchmark_sink ^= result; // consume the result outside the timed interval
        total_ns += std::chrono::duration_cast<std::chrono::nanoseconds>(stop - start).count();
    }
    return static_cast<double>(total_ns / (kTrials * kRepeatsPerTrial));
}
} // namespace

int main() {
    initialize_inputs(); // setup is deliberately outside both benchmarks

    const std::int64_t cpp_result = cpp_dot_product(a, b, kCount);
    const std::int64_t neon_result = neon_dot_product(a, b, kCount);
    if (cpp_result != neon_result) {
        std::cerr << "ERROR: result mismatch: C++=" << cpp_result
                  << ", NEON=" << neon_result << '\n';
        return EXIT_FAILURE;
    }

    const double cpp_ns = benchmark_ns_per_dot(cpp_dot_product);
    const double neon_ns = benchmark_ns_per_dot(neon_dot_product);

    std::cout << "elements: " << kCount << " (vector loop + 3-element tail)\n"
              << "dot product: " << neon_result << " (verified equal)\n"
              << std::fixed << std::setprecision(1)
              << "C++ -O3: " << cpp_ns << " ns/dot\n"
              << "hand-written NEON: " << neon_ns << " ns/dot\n"
              << std::setprecision(3)
              << "speedup: " << (cpp_ns / neon_ns) << "x\n";
    return benchmark_sink == 0x7fff'ffff'ffff'ffffLL; // preserves the volatile read
}
