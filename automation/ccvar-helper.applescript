-- CCVAR 撰稿助手 —— 双击即用的图形小工具（无需命令行）
property projDir : "/Users/apple/work/test.ccvar"

on manage(arg)
	return do shell script "/bin/bash " & quoted form of (projDir & "/automation/manage.sh") & " " & arg
end manage

repeat
	set statusText to "（无法读取状态）"
	try
		set statusText to manage("status")
	end try
	set actions to {"1) 立刻撰稿一篇（约数分钟）", "2) 看待审草稿", "3) 看最近运行日志", "4) 暂停每日自动撰稿", "5) 恢复每日自动撰稿", "6) 编辑选题 topics.md"}
	set picked to choose from list actions with title "CCVAR 撰稿助手" with prompt ("当前：" & statusText & return & return & "选择一个操作：") OK button name "执行" cancel button name "关闭" default items {item 1 of actions}
	if picked is false then exit repeat
	set act to item 1 of picked
	if act starts with "1)" then
		do shell script "cd " & quoted form of projDir & " && /usr/bin/nohup /bin/bash automation/run-daily.sh >/dev/null 2>&1 &"
		display notification "已开始撰稿，完成后会通知你（约数分钟）" with title "CCVAR 撰稿助手"
	else if act starts with "2)" then
		set q to do shell script "cd " & quoted form of projDir & " && /usr/bin/grep -F -- '- [ ]' review-queue.md || echo '（暂无待审草稿）'"
		display dialog ("后台待审的草稿：" & return & return & q) with title "待审草稿" buttons {"好"} default button "好"
	else if act starts with "3)" then
		display dialog manage("logs") with title "最近运行日志" buttons {"好"} default button "好"
	else if act starts with "4)" then
		display dialog manage("pause") with title "CCVAR 撰稿助手" buttons {"好"} default button "好"
	else if act starts with "5)" then
		display dialog manage("resume") with title "CCVAR 撰稿助手" buttons {"好"} default button "好"
	else if act starts with "6)" then
		do shell script "/usr/bin/open -t " & quoted form of (projDir & "/topics.md")
	end if
end repeat
