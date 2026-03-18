extends Control

@onready var progress_bar:  ProgressBar = $CenterContainer/VBoxContainer/ProgressBar
@onready var status_label:  Label       = $CenterContainer/VBoxContainer/StatusLabel
@onready var percent_label: Label       = $CenterContainer/VBoxContainer/PercentLabel

func _ready() -> void:
	progress_bar.value  = 0
	percent_label.text  = "0%"
	status_label.text   = "PREPARING…"

## Update both the bar and an optional explicit status message.
## If status is empty the label is driven by progress thresholds.
func update_progress(val: float, status: String = "") -> void:
	var pct = clamp(val * 100.0, 0.0, 100.0)
	progress_bar.value = pct
	percent_label.text = str(int(round(pct))) + "%"

	if status != "":
		status_label.text = status.to_upper()
	else:
		if val < 0.08:
			status_label.text = "PREPARING…"
		elif val < 0.50:
			status_label.text = "LOADING ASSETS…"
		elif val < 0.85:
			status_label.text = "ASSEMBLING…"
		elif val < 0.92:
			status_label.text = "BUILDING SCENE…"
		elif val < 1.0:
			status_label.text = "INITIALIZING…"
		else:
			status_label.text = "READY!"

## Set only the status label text (called by SceneManager.report_progress).
func set_status(status: String) -> void:
	status_label.text = status.to_upper()
