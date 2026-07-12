這是一個 host acceptance probe，不是實作任務。

限制：

- 不修改 repository 或 host 設定。
- 不建立 dispatch brief、不呼叫 `pmctl pm run`、不派工。
- 不 commit、push、建立 PR。
- 只使用 `/pm` 已提供的 preparation context，以及必要的唯讀 `pmctl` 查詢。
- 最長 120 秒；若 permission、trust prompt 或工具等待超時，立即回報，不要重試。

請確認以下事項：

1. `/pm` command 在目前 host 能正常載入。
2. `pmctl pm prepare` 的 working directory 是
   `/home/screenleon/github/pm-dispatch`。
3. focus tickets 包含 `CC-445`、`CC-448`，且 snapshot status 是
   `created`。
4. memory resolution 是 readable；記錄 resolution source、project key 與
   memory context status。沒有 memory hit 可以接受，但 query failure 不可接受。
5. 說明目前 host 的 `pm_command_interface` 與 `command_guard` effective
   capability；不要把 unsupported 能力寫成故障。
6. 整個 probe 沒有修改 tracked files。

只回傳一個 JSON code block，格式如下：

```json
{
  "schema": "host_acceptance_v1",
  "host": "claude-or-opencode",
  "pm_command_loaded": true,
  "prepare": {
    "working_dir": "/home/screenleon/github/pm-dispatch",
    "focus_tickets": ["CC-445", "CC-448"],
    "snapshot_status": "created",
    "memory_readable": true,
    "memory_resolution_source": "value",
    "memory_project_key": "value",
    "memory_context_status": "hydrated-or-no-hits"
  },
  "capabilities": {
    "pm_command_interface": "effective description",
    "command_guard": "effective description"
  },
  "tracked_files_modified": false,
  "unexpected_permission_prompt": false,
  "timed_out": false,
  "verdict": "PASS-or-FAIL",
  "notes": []
}
```

判定規則：任一 preparation invariant 不符、query-failed、非預期 permission
prompt、timeout 或 tracked file modification 都是 FAIL。能力本來就宣告為
`none` 不算 FAIL。
