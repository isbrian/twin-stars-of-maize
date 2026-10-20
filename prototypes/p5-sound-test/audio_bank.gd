extends RefCounted
# 音檔：缺檔檢查與載入（測驗與試聽共用）。音檔由 sync_audio.sh 複製進 audio/，不進版控。

const Quiz := preload("res://quiz.gd")
const DIR := "res://audio"


static func missing(dir := DIR) -> Array:
	return Quiz.all_files().filter(func(f): return not ResourceLoader.exists(dir.path_join(f)))


static func load_stream(file: String, dir := DIR) -> AudioStream:
	return load(dir.path_join(file))
