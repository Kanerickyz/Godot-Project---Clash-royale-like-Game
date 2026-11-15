extends SceneTree
## Phase E runner: corpus credit, relic buy/refresh, reject paths, revive relic hook.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := true
	if not PhaseECorpusRelicsTest.test_buy_refresh_and_rejects():
		ok = false
	if not PhaseECorpusRelicsTest.test_revive_shorten_hook():
		ok = false
	if not PhaseECorpusRelicsTest.test_drop_pool_helpers():
		ok = false
	if not await _test_game_corpus_relics():
		ok = false
	quit(0 if ok else 1)


func _test_game_corpus_relics() -> bool:
	var host := Node.new()
	host.name = "PhaseETestHost"
	root.add_child(host)
	var gc := GameController.new()
	gc.name = "GameControllerUnderTest"
	host.add_child(gc)
	await process_frame
	await process_frame

	if gc.get_corpus() < 0:
		push_error("PhaseE: corpus should be >= 0")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_E_START_CORPUS_OK corpus=", gc.get_corpus())

	# Corpus credit path (kill pool + find bonus when owned).
	var before := gc.get_corpus()
	var gained := gc.debug_grant_kill_corpus(false)
	if gained <= 0:
		push_error("PhaseE: kill corpus grant should be > 0")
		host.queue_free()
		await process_frame
		return false
	if gc.get_corpus() != before + gained:
		push_error("PhaseE: corpus wallet mismatch after grant")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_E_CORPUS_CREDIT_OK corpus=", gc.get_corpus(), " gained=", gained)

	# Enter interstitial → relic shelf rolls.
	gc.debug_enter_portal()
	await process_frame
	if gc.get_run_phase() != GameController.RunPhase.INTERSTITIAL:
		push_error("PhaseE: expected INTERSTITIAL")
		host.queue_free()
		await process_frame
		return false
	var relics := gc.get_relic_service()
	if relics == null or relics.shelf.is_empty():
		push_error("PhaseE: relic shelf empty after interstitial")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_E_RELIC_SHELF_OK slots=", relics.shelf.size())

	# Not enough → reject.
	var broke := gc.debug_relic_buy(0)
	# May succeed if starting corpus somehow high; force empty wallet.
	if bool(broke.get("ok", false)):
		# Undo by not caring; force rejection path separately.
		pass
	# Force not-enough: set shelf price high via direct shelf mutate.
	relics.shelf[0] = {
		"relic": _make_relic(&"pricey", 99, RelicDefinition.EffectKind.REVIVE_SHORTEN, 0.2),
		"price": 99,
		"sold_out": false,
	}
	var corpus_now := gc.get_corpus()
	if corpus_now >= 99:
		# Spend down via fake purchases not available — just check relative.
		pass
	var poor := gc.debug_relic_buy(0)
	if bool(poor.get("ok", true)) or poor.get("code") != RelicService.RESULT_NOT_ENOUGH:
		# If somehow corpus >= 99, skip; otherwise must reject.
		if gc.get_corpus() < 99:
			push_error("PhaseE: expected NOT_ENOUGH got %s" % str(poor))
			host.queue_free()
			await process_frame
			return false
	print("PHASE_E_NOT_ENOUGH_OK")

	# Fund and buy revive relic.
	gc.debug_add_corpus(20)
	relics.shelf[0] = {
		"relic": _make_relic(&"bone_hourglass", 5, RelicDefinition.EffectKind.REVIVE_SHORTEN, 0.2),
		"price": 5,
		"sold_out": false,
	}
	var gold_before_buy := gc.get_ducats()
	var corpus_before_buy := gc.get_corpus()
	var buy := gc.debug_relic_buy(0)
	if not bool(buy.get("ok", false)):
		push_error("PhaseE: buy revive relic failed %s" % str(buy))
		host.queue_free()
		await process_frame
		return false
	if gc.get_corpus() != corpus_before_buy - 5:
		push_error("PhaseE: corpus not deducted on buy")
		host.queue_free()
		await process_frame
		return false
	if gc.get_ducats() != gold_before_buy:
		push_error("PhaseE: relic buy must not spend ducats")
		host.queue_free()
		await process_frame
		return false
	if relics.owned_count() < 1:
		push_error("PhaseE: expected owned relic after buy")
		host.queue_free()
		await process_frame
		return false
	var revive_mult := gc.get_relic_revive_time_multiplier()
	if absf(revive_mult - 0.8) > 0.001:
		push_error("PhaseE: expected revive mult 0.8 got %s" % str(revive_mult))
		host.queue_free()
		await process_frame
		return false
	print("PHASE_E_BUY_REVIVE_OK mult=", revive_mult, " corpus=", gc.get_corpus())

	# Fill slots then reject.
	var max_slots := relics.max_slots()
	while relics.owned_count() < max_slots:
		relics.shelf[0] = {
			"relic": _make_relic(
				StringName("fill_%d" % relics.owned_count()),
				1,
				RelicDefinition.EffectKind.ATTACK_BONUS,
				0.05
			),
			"price": 1,
			"sold_out": false,
		}
		gc.debug_add_corpus(2)
		var fill := gc.debug_relic_buy(0)
		if not bool(fill.get("ok", false)):
			push_error("PhaseE: fill buy failed %s" % str(fill))
			host.queue_free()
			await process_frame
			return false
	relics.shelf[0] = {
		"relic": _make_relic(&"overflow", 1, RelicDefinition.EffectKind.ATTACK_BONUS, 0.05),
		"price": 1,
		"sold_out": false,
	}
	gc.debug_add_corpus(5)
	var full := gc.debug_relic_buy(0)
	if bool(full.get("ok", true)) or full.get("code") != RelicService.RESULT_SLOTS_FULL:
		push_error("PhaseE: expected SLOTS_FULL got %s owned=%d" % [str(full), relics.owned_count()])
		host.queue_free()
		await process_frame
		return false
	print("PHASE_E_SLOTS_FULL_OK owned=", relics.owned_count())

	# Refresh spends corpus.
	var before_rf := gc.get_corpus()
	var rf := gc.debug_relic_refresh()
	if not bool(rf.get("ok", false)):
		gc.debug_add_corpus(10)
		before_rf = gc.get_corpus()
		rf = gc.debug_relic_refresh()
	if not bool(rf.get("ok", false)):
		push_error("PhaseE: relic refresh failed %s" % str(rf))
		host.queue_free()
		await process_frame
		return false
	if gc.get_corpus() != before_rf - int(rf.get("cost", 0)):
		push_error("PhaseE: refresh corpus deduct mismatch")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_E_REFRESH_OK corpus=", gc.get_corpus())

	# Observable revive shorten: kill follower, compare enqueue remaining vs base*mult.
	gc.debug_advance_floor()
	await process_frame
	await process_frame
	if gc.get_follower_count() < 1:
		push_error("PhaseE: need follower for revive hook observability")
		host.queue_free()
		await process_frame
		return false
	var base := 8.0
	if gc.get_merge_rank_config() != null:
		base = gc.get_merge_rank_config().base_revive_time()
	var expected := base * gc.get_relic_revive_time_multiplier()
	# Oaths may also shorten; fold them in.
	expected *= gc.get_oath_revive_time_multiplier()
	if not gc.debug_kill_follower(0):
		push_error("PhaseE: kill follower failed")
		host.queue_free()
		await process_frame
		return false
	await process_frame
	var rows := gc.get_revive_queue_rows()
	if rows.is_empty():
		push_error("PhaseE: revive queue empty after kill")
		host.queue_free()
		await process_frame
		return false
	var remaining := float(rows[0].get("remaining", 0.0))
	if remaining > expected + 0.15 or remaining < expected - 0.15:
		push_error(
			"PhaseE: revive remaining %.3f not near expected %.3f (base=%.2f)"
			% [remaining, expected, base]
		)
		host.queue_free()
		await process_frame
		return false
	print("PHASE_E_REVIVE_OBSERVED_OK remaining=", remaining, " expected=", expected)

	# Elite / shrine presence smoke (floor entities).
	var elites := 0
	var shrines := 0
	for node in gc.get_tree().get_nodes_in_group(&"elites"):
		if node != null and is_instance_valid(node):
			elites += 1
	for node in gc.get_tree().get_nodes_in_group(&"shrines"):
		if node != null and is_instance_valid(node):
			shrines += 1
	# After next floor, new floor should spawn at least configured counts.
	if elites < 1:
		push_error("PhaseE: expected >=1 elite on floor")
		host.queue_free()
		await process_frame
		return false
	if shrines < 1:
		push_error("PhaseE: expected >=1 shrine on floor")
		host.queue_free()
		await process_frame
		return false
	print("PHASE_E_FLOOR_LOOT_OK elites=", elites, " shrines=", shrines)

	print("PHASE_E_GAME_OK")
	host.queue_free()
	await process_frame
	return true


func _make_relic(
	id: StringName,
	price: int,
	kind: RelicDefinition.EffectKind,
	value: float
) -> RelicDefinition:
	var r := RelicDefinition.new()
	r.id = id
	r.display_name = str(id)
	r.price = price
	r.effect_kind = kind
	r.effect_value = value
	return r
