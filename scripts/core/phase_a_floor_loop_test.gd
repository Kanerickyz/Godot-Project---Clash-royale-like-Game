class_name PhaseAFloorLoopTest
extends RefCounted
## Phase A pure logic checks (threat clock). Game flow lives in the runner.


static func test_threat_clock_rises() -> bool:
	var cfg := ThreatConfig.new()
	cfg.base_multiplier = 1.0
	cfg.max_multiplier = 2.5
	cfg.ramp_duration = 100.0
	cfg.tier_thresholds = PackedFloat32Array([1.0, 1.25, 1.6, 2.0])
	var clock := ThreatClock.new()
	clock.configure(cfg)
	var m0 := clock.get_multiplier()
	clock.tick(50.0)
	var m1 := clock.get_multiplier()
	clock.tick(50.0)
	var m2 := clock.get_multiplier()
	if m1 <= m0:
		push_error("PhaseAFloorLoopTest: threat multiplier did not rise after 50s (%.3f → %.3f)" % [m0, m1])
		return false
	if m2 <= m1:
		push_error("PhaseAFloorLoopTest: threat multiplier did not rise after 100s (%.3f → %.3f)" % [m1, m2])
		return false
	if absf(m2 - cfg.max_multiplier) > 0.05:
		push_error("PhaseAFloorLoopTest: expected ~max mult %.2f got %.3f" % [cfg.max_multiplier, m2])
		return false
	print("PHASE_A_THREAT_OK m0=%.3f m1=%.3f m2=%.3f" % [m0, m1, m2])
	return true
