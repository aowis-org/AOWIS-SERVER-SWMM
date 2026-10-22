#include "aowis/swmm/Simulation.hpp"

#include <filesystem>
#include <iostream>
#include <stdexcept>

int main(int argc, char** argv) {
    if (argc != 4) {
        std::cerr << "Usage: aowis-swmm-smoke INPUT.inp REPORT.rpt OUTPUT.out\n";
        return 2;
    }

    try {
        const std::filesystem::path input(argv[1]);
        const std::filesystem::path report(argv[2]);
        const std::filesystem::path output(argv[3]);
        std::filesystem::remove(report);
        std::filesystem::remove(output);

        const auto result = aowis::swmm::runSimulation(input, report, output);
        if (result.engineVersion < 50000) {
            std::cerr << "Unexpected SWMM engine version: " << result.engineVersion << '\n';
            return 1;
        }
        if (result.errorCode != 0) {
            std::cerr << "SWMM simulation failed with code " << result.errorCode << '\n';
            return 1;
        }
        if (!std::filesystem::is_regular_file(report) ||
            !std::filesystem::is_regular_file(output) ||
            std::filesystem::file_size(report) == 0 ||
            std::filesystem::file_size(output) == 0) {
            std::cerr << "SWMM did not produce nonempty report and binary output files\n";
            return 1;
        }
        std::cout << "SWMM " << result.engineVersion
                  << ": simulation succeeded; report=" << report
                  << ", output=" << output << '\n';
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "SWMM smoke test error: " << error.what() << '\n';
        return 1;
    }
}
