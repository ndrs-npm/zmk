## file: build_crkbd_fw.sh
## brief: Script to build ZMK firmware for Corne keyboard (left and right sides)

# ------------------------------------------------------------------------------------------------ #
# INTRODUCTION: Build ZMK firmware for Corne keyboard (left, right, or settings reset).
#               Usage: ./build_crkbd_fw.sh [left|right|reset]
#
# AUTHOR(S): honest
#
# REFERENCES DOCUMENTS :
# - ZMK Firmware: https://zmk.dev/docs
# - ZMK Local toolchain setup: https://zmk.dev/docs/development/local-toolchain/setup
# - ZMK Building and flashing: https://zmk.dev/docs/development/local-toolchain/build-flash
#
# NOTE:
# - N/A
#
# ------------------------------------------------------------------------------------------------ #

#!/bin/bash

SIDE=$1   # left or right

# Return value constants
readonly E_OK=0
readonly E_NOT_OK=1

# Function to format time in seconds to human readable format
format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))

    if [ $minutes -eq 0 ]; then
        echo "${remaining_seconds}s"
    else
        echo "${minutes}m ${remaining_seconds}s"
    fi
}

# Function to build a specific side
build_side() {
    local side=$1
    local start_time=$(date +%s)

    echo "Building ${side} side..."

    west build -s app/ -p -d build/corne_${side} -b nice_nano_v2 -- \
        -DSHIELD=corne_${side} \
        -DZMK_CONFIG=/workspaces/zmk/zmk-config/config

    local build_result=$?
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    local formatted_time=$(format_time $build_time)

    if [ $build_result -eq $E_OK ]; then
        # Check if the firmware file actually exists before copying
        if [ -f "build/corne_${side}/zephyr/zmk.uf2" ]; then
            cp build/corne_${side}/zephyr/zmk.uf2 build/corne_${side}.uf2
            echo -e "\e[32m✓ ${side} side build completed successfully in ${formatted_time}!\e[0m"
            echo "Firmware saved as: build/corne_${side}.uf2"
            return $E_OK
        else
            echo -e "\e[31m✗ ${side} side build failed - firmware file not found after ${formatted_time}!\e[0m"
            return $E_NOT_OK
        fi
    else
        echo -e "\e[31m✗ ${side} side build failed after ${formatted_time}!\e[0m"
        return $E_NOT_OK
    fi
}

# Add this function to your script
build_settings_reset() {
    local start_time=$(date +%s)

    echo "Building settings reset firmware..."

    west build -s app/ -p -d build/settings_reset -b nice_nano_v2 -- \
        -DSHIELD=settings_reset \
        -DZMK_CONFIG=/workspaces/zmk/zmk-config/config

    local build_result=$?
    local end_time=$(date +%s)
    local build_time=$((end_time - start_time))
    local formatted_time=$(format_time $build_time)

    if [ $build_result -eq $E_OK ]; then
        if [ -f "build/settings_reset/zephyr/zmk.uf2" ]; then
            cp build/settings_reset/zephyr/zmk.uf2 build/settings_reset.uf2
            echo -e "\e[32m✓ Settings reset firmware built successfully in ${formatted_time}!\e[0m"
            echo "Firmware saved as: build/settings_reset.uf2"
            return $E_OK
        else
            echo -e "\e[31m✗ Settings reset build failed - firmware file not found after ${formatted_time}!\e[0m"
            return $E_NOT_OK
        fi
    else
        echo -e "\e[31m✗ Settings reset build failed after ${formatted_time}!\e[0m"
        return $E_NOT_OK
    fi
}

# If argument provided, validate it
if [ -n "$SIDE" ]; then
    if [ "$SIDE" != "left" ] && [ "$SIDE" != "right" ] && [ "$SIDE" != "reset" ]; then
        echo "Error: Invalid argument '$SIDE'. Only 'left', 'right', or 'reset' are allowed."
        echo "Usage: $0 {left|right|reset}"
        exit $E_NOT_OK
    fi

    if [ "$SIDE" == "reset" ]; then
        total_start=$(date +%s)
        build_settings_reset
        build_result=$?
        total_end=$(date +%s)
        total_time=$((total_end - total_start))
        echo
        echo -e "\e[36mTotal build time: $(format_time $total_time)\e[0m"
        exit $build_result
    fi

    # Build specified side and track total time
    total_start=$(date +%s)
    build_side "$SIDE"
    if [ $? -eq $E_OK ]; then
        total_end=$(date +%s)
        total_time=$((total_end - total_start))
        echo
        echo -e "\e[36mTotal build time: $(format_time $total_time)\e[0m"
        exit $E_OK
    else
        exit $E_NOT_OK
    fi
else
    # No argument provided, prompt user
    echo "No side specified."
    echo "Would you like to build both left and right sides? (y/N): "
    read -r response

    if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
        echo "Building both sides..."
        echo

        # Create build directory if it doesn't exist
        mkdir -p build

        # Track total time for both builds
        total_start=$(date +%s)

        # Build left side first
        build_side "left"
        if [ $? -ne $E_OK ]; then
            echo "Left side build failed. Stopping."
            exit $E_NOT_OK
        fi

        echo

        # Build right side
        build_side "right"
        if [ $? -ne $E_OK ]; then
            echo "Right side build failed."
            exit $E_NOT_OK
        fi

        total_end=$(date +%s)
        total_time=$((total_end - total_start))

        echo
        echo "============================================================"
        echo -e "\e[32m🎉 Both sides built successfully!\e[0m"
        echo "Firmware files:"
        echo "  - Left:  build/left.uf2"
        echo "  - Right: build/right.uf2"
        echo "------------------------------------------------------------"
        echo -e "\e[36mBuild time summary:\e[0m"
        echo "  - Total time: $(format_time $total_time)"
        echo "============================================================"
        exit $E_OK
    else
        echo "============================================================"
        echo -e "\e[31mBuild cancelled.\e[0m"
        echo "Usage: $0 {left|right} or run without arguments to build both sides"
        echo "============================================================"
        exit $E_NOT_OK
    fi
fi
