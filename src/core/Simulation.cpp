#include "aowis/swmm/Simulation.hpp"

#include <swmm5.h>

#include <mutex>
#include <stdexcept>

namespace aowis::swmm {
namespace {
std::mutex& solverMutex() {
    static std::mutex mutex;
    return mutex;
}
}  // namespace

int engineVersion() {
    std::lock_guard<std::mutex> lock(solverMutex());
    return swmm_getVersion();
}

SimulationResult runSimulation(const std::filesystem::path& input,
                               const std::filesystem::path& report,
                               const std::filesystem::path& binaryOutput) {
    if (input.empty() || report.empty() || binaryOutput.empty()) {
        throw std::invalid_argument("SWMM input, report and output paths are required");
    }
    if (input == report || input == binaryOutput || report == binaryOutput) {
        throw std::invalid_argument("SWMM input, report and output paths must differ");
    }
    // OWA's C SWMM implementation is process-global. Keep all core entrypoints
    // under this same mutex. Never call it directly on an independent thread.
    std::lock_guard<std::mutex> lock(solverMutex());
    const int version = swmm_getVersion();
    const int status = swmm_run(input.string().c_str(), report.string().c_str(),
                                binaryOutput.string().c_str());
    return {status, version};
}

}  // namespace aowis::swmm
