export class AssistantTimeService {
  static dateString(value: Date): string {
    return value.getFullYear() + '-' + ('0' + (value.getMonth() + 1)).slice(-2) + '-' + ('0' + value.getDate()).slice(-2);
  }

  static timestamp(date: string, time: string): number {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^\d{2}:\d{2}$/.test(time)) return 0;
    const parts: string[] = date.split('-'); const clock: string[] = time.split(':');
    const value = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), Number(clock[0]), Number(clock[1]));
    return AssistantTimeService.dateString(value) === date && value.getHours() === Number(clock[0]) &&
      value.getMinutes() === Number(clock[1]) ? value.getTime() : 0;
  }
}
