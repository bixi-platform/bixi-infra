# ── Collector Lambda ──────────────────────────────────────────────────────────
# Go binary (arm64, provided.al2023 runtime).
# Built by: make lambda-build in bixi-collector/
# Zip uploaded to S3 by CI before terraform apply.

resource "aws_lambda_function" "collector" {
  function_name = "${local.name_prefix}-collector"
  description   = "GBFS + weather collector — runs every 2 minutes"
  role          = aws_iam_role.collector.arn

  # Zip uploaded to S3 by build pipeline
  s3_bucket = aws_s3_bucket.lambda_zips.id
  s3_key    = "collector.zip"

  runtime       = "provided.al2023"
  architectures = ["arm64"]
  handler       = "bootstrap" # Go Lambda convention

  timeout     = 60 # 1 minute max; one poll cycle is <5s
  memory_size = 128

  environment {
    variables = {
      DATABASE_URL = local.resolved_database_url
    }
  }

  depends_on = [aws_iam_role_policy_attachment.collector_basic]
}

# EventBridge rule: fire every 2 minutes
resource "aws_cloudwatch_event_rule" "collector" {
  name                = "${local.name_prefix}-collector-schedule"
  description         = "Trigger GBFS collector every 2 minutes"
  schedule_expression = "rate(2 minutes)"
}

resource "aws_cloudwatch_event_target" "collector" {
  rule      = aws_cloudwatch_event_rule.collector.name
  target_id = "CollectorLambda"
  arn       = aws_lambda_function.collector.arn
}

resource "aws_lambda_permission" "collector_eventbridge" {
  statement_id  = "AllowEventBridgeInvokeCollector"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.collector.arn
}

# ── Inference Lambda ──────────────────────────────────────────────────────────
# Python 3.12. Heavy packages (xgboost, pandas, psycopg2) in a Lambda Layer.
# Built by: make lambda-build in bixi-ml/

resource "aws_lambda_function" "inference" {
  function_name = "${local.name_prefix}-inference"
  description   = "Batch inference — writes predictions to features_cache every 2 min"
  role          = aws_iam_role.inference.arn

  s3_bucket = aws_s3_bucket.lambda_zips.id
  s3_key    = "inference.zip"

  runtime = "python3.12"
  handler = "lambda_handler.handler"

  timeout     = 120 # 2 minutes; inference for ~1000 stations takes ~10-30s
  memory_size = 512

  layers = [aws_lambda_layer_version.inference_deps.arn]

  environment {
    variables = {
      DATABASE_URL = local.resolved_database_url
      MODEL_BUCKET = aws_s3_bucket.models.bucket
      MODEL_PREFIX = "phase1" # overridden to phase2/phase3 as models are promoted
    }
  }

  depends_on = [aws_iam_role_policy_attachment.inference_basic]
}

# Lambda Layer: xgboost, pandas, psycopg2-binary, joblib, scikit-learn, numpy
# Built by: make lambda-layer in bixi-ml/
resource "aws_lambda_layer_version" "inference_deps" {
  layer_name               = "${local.name_prefix}-inference-deps"
  description              = "Python ML deps: xgboost, pandas, psycopg2, joblib, scikit-learn"
  s3_bucket                = aws_s3_bucket.lambda_zips.id
  s3_key                   = "inference-layer.zip"
  compatible_runtimes      = ["python3.12"]
  compatible_architectures = ["x86_64"]
}

# EventBridge rule: fire every 2 minutes (offset from collector by design)
resource "aws_cloudwatch_event_rule" "inference" {
  name                = "${local.name_prefix}-inference-schedule"
  description         = "Trigger batch inference every 2 minutes"
  schedule_expression = "rate(2 minutes)"
}

resource "aws_cloudwatch_event_target" "inference" {
  rule      = aws_cloudwatch_event_rule.inference.name
  target_id = "InferenceLambda"
  arn       = aws_lambda_function.inference.arn
}

resource "aws_lambda_permission" "inference_eventbridge" {
  statement_id  = "AllowEventBridgeInvokeInference"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inference.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inference.arn
}

# ── CloudWatch log groups (explicit so retention is set) ─────────────────────

resource "aws_cloudwatch_log_group" "collector" {
  name              = "/aws/lambda/${aws_lambda_function.collector.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "inference" {
  name              = "/aws/lambda/${aws_lambda_function.inference.function_name}"
  retention_in_days = 14
}
