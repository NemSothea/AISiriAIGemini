import { insightIntent } from '@kit.AbilityKit';

export function ok(message: string): Promise<insightIntent.IntentResult<string>> {
  const result: insightIntent.IntentResult<string> = { code: 0, result: message };
  return Promise.resolve(result);
}

export function fail(message: string): Promise<insightIntent.IntentResult<string>> {
  const result: insightIntent.IntentResult<string> = { code: -1, result: message };
  return Promise.resolve(result);
}
