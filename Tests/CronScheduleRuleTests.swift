import Foundation

func expectCronRule(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        print("FAIL: \(message)")
        exit(1)
    }
}

func testRecognizesCommonRules() {
    expectCronRule(CronScheduleRule(expression: "15 * * * *").kind == .hourly, "hourly rule should be recognized")
    expectCronRule(CronScheduleRule(expression: "30 9 * * *").kind == .daily, "daily rule should be recognized")
    expectCronRule(CronScheduleRule(expression: "30 9 * * 1-5").kind == .weekdays, "weekday rule should be recognized")
    expectCronRule(CronScheduleRule(expression: "0 18 * * 1,3,5").kind == .weekly, "weekly rule should be recognized")
    expectCronRule(CronScheduleRule(expression: "0 10 15 * *").kind == .monthly, "monthly rule should be recognized")
}

func testGeneratedExpressions() {
    var weekly = CronScheduleRule(expression: "0 9 * * 1-5")
    weekly.kind = .weekly
    weekly.hour = 18
    weekly.minute = 5
    weekly.weekdays = [0, 2, 4]
    expectCronRule(weekly.expression == "5 18 * * 0,2,4", "weekly selection should generate a stable expression")
    expectCronRule(weekly.summary == "每周二、四、日 18:05", "weekly selection should generate a readable summary")

    var monthly = CronScheduleRule(expression: "0 9 * * *")
    monthly.kind = .monthly
    monthly.monthDay = 20
    monthly.hour = 8
    monthly.minute = 30
    expectCronRule(monthly.expression == "30 8 20 * *", "monthly selection should generate an expression")
}

func testKeepsAdvancedExpressionsCustom() {
    let source = "*/10 8-18 * * 1-5"
    let rule = CronScheduleRule(expression: source)
    expectCronRule(rule.kind == .custom, "advanced expression should stay in custom mode")
    expectCronRule(rule.expression == source, "advanced expression should be preserved")
}

func testCustomDraftSurvivesRoundTripThroughPresetKinds() {
    let source = "*/10 8-18 * * 1-5"
    var rule = CronScheduleRule(expression: source)
    expectCronRule(rule.kind == .custom, "advanced expression should start in custom mode")

    // 切到预设规则：自定义草稿必须保留，而不是被生成的表达式覆盖
    rule.kind = .daily
    expectCronRule(rule.expression == "0 9 * * *", "preset kind should generate its own expression")
    expectCronRule(rule.customExpression == source, "switching away should keep the custom draft")

    rule.kind = .custom
    expectCronRule(rule.expression == source, "switching back should restore the custom draft")
}

func testReinterpretPreservesCustomDraft() {
    let draft = "*/10 8-18 * * 1-5"
    var rule = CronScheduleRule(expression: draft)

    rule.reinterpret(expression: "0 9 * * *", preservingCustomDraft: draft)
    expectCronRule(rule.kind == .daily, "reinterpret should pick up the recognized preset kind")
    expectCronRule(rule.customExpression == draft, "reinterpret should retain the supplied draft")

    rule.reinterpret(expression: "*/5 * * * *", preservingCustomDraft: draft)
    expectCronRule(rule.kind == .custom, "unrecognized expression should fall back to custom")
    expectCronRule(rule.expression == "*/5 * * * *", "custom mode should use the reinterpreted expression")
}

func testHourlyRuleIgnoresHourField() {
    var rule = CronScheduleRule(expression: "0 9 * * *")
    rule.kind = .hourly
    rule.minute = 45
    expectCronRule(rule.expression == "45 * * * *", "hourly rule should only pin the minute")
    expectCronRule(rule.summary == "每小时第 45 分钟", "hourly summary should mention only the minute")
}

@main
struct CronScheduleRuleTestRunner {
    static func main() {
        testRecognizesCommonRules()
        testGeneratedExpressions()
        testKeepsAdvancedExpressionsCustom()
        testCustomDraftSurvivesRoundTripThroughPresetKinds()
        testReinterpretPreservesCustomDraft()
        testHourlyRuleIgnoresHourField()
        print("PASS")
    }
}
