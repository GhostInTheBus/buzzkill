#!/bin/zsh
# Build DesktopFly
set -e
cd "$(dirname "$0")"
swiftc -module-cache-path "${TMPDIR:-/tmp}/desktopfly-module-cache" -O -wmo -enforce-exclusivity=unchecked -swift-version 5 -o Buzzkill main.swift FlyModel.swift LegDynamics.swift Locomotor.swift LocomotorTests.swift BeetleModel.swift Sim.swift BrainView.swift \
    Environment.swift Game/*.swift Senses/*.swift Audio/*.swift -framework Cocoa -framework SceneKit -framework AVFoundation
echo "Built ./Buzzkill"
