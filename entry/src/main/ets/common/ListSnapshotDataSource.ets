/** Immutable list snapshot. Replace it when filtering/refreshing instead of
 * constructing every off-screen card inside a Scroll + Column. */
export class ListSnapshotDataSource<T> implements IDataSource {
  private readonly items: T[];

  constructor(items: T[]) { this.items = items; }
  totalCount(): number { return this.items.length; }
  getData(index: number): T { return this.items[index]; }
  // Snapshots never mutate; List subscribes to a new instance on replacement.
  registerDataChangeListener(listener: DataChangeListener): void {}
  unregisterDataChangeListener(listener: DataChangeListener): void {}
}
