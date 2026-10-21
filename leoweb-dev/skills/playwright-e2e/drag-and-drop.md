# Recettes de drag and drop

> **Quand l'utiliser** : Tu dois tester des interactions de drag and drop -- listes triables, tableaux kanban, zones de dépôt de fichiers, ou tout élément repositionnable par glisser.

---

## Recette 1 : Drag and drop HTML5 natif

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('drags an item from one container to another', async ({ page }) => {
  await page.goto('/drag-demo');

  const sourceItem = page.getByText('Draggable Item');
  const dropZone = page.locator('#drop-zone');

  // Verify initial state
  await expect(sourceItem).toBeVisible();
  await expect(dropZone).not.toContainText('Draggable Item');

  // Perform drag and drop
  await sourceItem.dragTo(dropZone);

  // Verify the item moved to the drop zone
  await expect(dropZone).toContainText('Draggable Item');
});

test('drags between two drop zones using locators', async ({ page }) => {
  await page.goto('/drag-demo');

  const item = page.locator('[data-testid="item-1"]');
  const zoneA = page.locator('[data-testid="zone-a"]');
  const zoneB = page.locator('[data-testid="zone-b"]');

  // Item starts in zone A
  await expect(zoneA).toContainText('Item 1');

  // Drag to zone B
  await item.dragTo(zoneB);

  // Item is now in zone B, not zone A
  await expect(zoneB).toContainText('Item 1');
  await expect(zoneA).not.toContainText('Item 1');

  // Drag back to zone A
  await zoneB.getByText('Item 1').dragTo(zoneA);

  await expect(zoneA).toContainText('Item 1');
  await expect(zoneB).not.toContainText('Item 1');
});

test('verifies drag visual feedback', async ({ page }) => {
  await page.goto('/drag-demo');

  const sourceItem = page.getByText('Draggable Item');
  const dropZone = page.locator('#drop-zone');

  // Start drag manually to check intermediate states
  await sourceItem.hover();
  await page.mouse.down();

  // Move toward the drop zone
  const dropBox = await dropZone.boundingBox();
  await page.mouse.move(dropBox!.x + dropBox!.width / 2, dropBox!.y + dropBox!.height / 2);

  // Verify the drop zone shows a visual indicator while hovering
  await expect(dropZone).toHaveClass(/drag-over|highlight/);

  // Complete the drop
  await page.mouse.up();

  // Verify drop zone returns to normal styling
  await expect(dropZone).not.toHaveClass(/drag-over|highlight/);
  await expect(dropZone).toContainText('Draggable Item');
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('drags an item from one container to another', async ({ page }) => {
  await page.goto('/drag-demo');

  const sourceItem = page.getByText('Draggable Item');
  const dropZone = page.locator('#drop-zone');

  await expect(sourceItem).toBeVisible();
  await expect(dropZone).not.toContainText('Draggable Item');

  await sourceItem.dragTo(dropZone);

  await expect(dropZone).toContainText('Draggable Item');
});

test('drags between two drop zones', async ({ page }) => {
  await page.goto('/drag-demo');

  const item = page.locator('[data-testid="item-1"]');
  const zoneA = page.locator('[data-testid="zone-a"]');
  const zoneB = page.locator('[data-testid="zone-b"]');

  await expect(zoneA).toContainText('Item 1');

  await item.dragTo(zoneB);

  await expect(zoneB).toContainText('Item 1');
  await expect(zoneA).not.toContainText('Item 1');
});
```

---

## Recette 2 : Listes triables (réordonnancement des éléments)

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('reorders items in a sortable list', async ({ page }) => {
  await page.goto('/tasks');

  const list = page.getByRole('list', { name: 'Task list' });

  // Verify initial order
  const initialItems = await list.getByRole('listitem').allTextContents();
  expect(initialItems[0]).toContain('Task A');
  expect(initialItems[1]).toContain('Task B');
  expect(initialItems[2]).toContain('Task C');

  // Drag Task C to the top (above Task A)
  const taskC = list.getByRole('listitem').filter({ hasText: 'Task C' });
  const taskA = list.getByRole('listitem').filter({ hasText: 'Task A' });

  await taskC.dragTo(taskA);

  // Verify new order
  const reorderedItems = await list.getByRole('listitem').allTextContents();
  expect(reorderedItems[0]).toContain('Task C');
  expect(reorderedItems[1]).toContain('Task A');
  expect(reorderedItems[2]).toContain('Task B');
});

test('reorders using drag handle', async ({ page }) => {
  await page.goto('/tasks');

  const list = page.getByRole('list', { name: 'Task list' });

  // Use the drag handle (grip icon) instead of the whole item
  const dragHandle = list
    .getByRole('listitem')
    .filter({ hasText: 'Task C' })
    .getByRole('button', { name: /drag|reorder|grip/i });

  const targetItem = list.getByRole('listitem').filter({ hasText: 'Task A' });

  await dragHandle.dragTo(targetItem);

  const reorderedItems = await list.getByRole('listitem').allTextContents();
  expect(reorderedItems[0]).toContain('Task C');
});

test('reorder persists after page reload', async ({ page }) => {
  await page.goto('/tasks');

  const list = page.getByRole('list', { name: 'Task list' });

  const taskC = list.getByRole('listitem').filter({ hasText: 'Task C' });
  const taskA = list.getByRole('listitem').filter({ hasText: 'Task A' });

  await taskC.dragTo(taskA);

  // Wait for the save API call to complete
  await page.waitForResponse((response) =>
    response.url().includes('/api/tasks/reorder') && response.status() === 200
  );

  // Reload and verify persistence
  await page.reload();

  const items = await list.getByRole('listitem').allTextContents();
  expect(items[0]).toContain('Task C');
  expect(items[1]).toContain('Task A');
  expect(items[2]).toContain('Task B');
});

test('reorders with precise mouse movements for libraries that need it', async ({ page }) => {
  await page.goto('/tasks');

  const list = page.getByRole('list', { name: 'Task list' });
  const sourceItem = list.getByRole('listitem').filter({ hasText: 'Task C' });
  const targetItem = list.getByRole('listitem').filter({ hasText: 'Task A' });

  const sourceBox = await sourceItem.boundingBox();
  const targetBox = await targetItem.boundingBox();

  // Some drag libraries (react-beautiful-dnd, dnd-kit) require specific mouse event sequences
  await sourceItem.hover();
  await page.mouse.down();

  // Move in small steps -- some libraries require incremental movement to register
  const steps = 10;
  for (let i = 1; i <= steps; i++) {
    await page.mouse.move(
      sourceBox!.x + sourceBox!.width / 2,
      sourceBox!.y + (targetBox!.y - sourceBox!.y) * (i / steps),
      { steps: 1 }
    );
  }

  await page.mouse.up();

  const items = await list.getByRole('listitem').allTextContents();
  expect(items[0]).toContain('Task C');
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('reorders items in a sortable list', async ({ page }) => {
  await page.goto('/tasks');

  const list = page.getByRole('list', { name: 'Task list' });

  const initialItems = await list.getByRole('listitem').allTextContents();
  expect(initialItems[0]).toContain('Task A');
  expect(initialItems[1]).toContain('Task B');
  expect(initialItems[2]).toContain('Task C');

  const taskC = list.getByRole('listitem').filter({ hasText: 'Task C' });
  const taskA = list.getByRole('listitem').filter({ hasText: 'Task A' });

  await taskC.dragTo(taskA);

  const reorderedItems = await list.getByRole('listitem').allTextContents();
  expect(reorderedItems[0]).toContain('Task C');
  expect(reorderedItems[1]).toContain('Task A');
  expect(reorderedItems[2]).toContain('Task B');
});

test('reorders with precise mouse movements', async ({ page }) => {
  await page.goto('/tasks');

  const list = page.getByRole('list', { name: 'Task list' });
  const sourceItem = list.getByRole('listitem').filter({ hasText: 'Task C' });
  const targetItem = list.getByRole('listitem').filter({ hasText: 'Task A' });

  const sourceBox = await sourceItem.boundingBox();
  const targetBox = await targetItem.boundingBox();

  await sourceItem.hover();
  await page.mouse.down();

  const steps = 10;
  for (let i = 1; i <= steps; i++) {
    await page.mouse.move(
      sourceBox.x + sourceBox.width / 2,
      sourceBox.y + (targetBox.y - sourceBox.y) * (i / steps),
      { steps: 1 }
    );
  }

  await page.mouse.up();

  const items = await list.getByRole('listitem').allTextContents();
  expect(items[0]).toContain('Task C');
});
```

---

## Recette 3 : Tableau kanban (déplacement entre colonnes)

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('moves a card from Todo to In Progress', async ({ page }) => {
  await page.goto('/board');

  const todoColumn = page.locator('[data-column="todo"]');
  const inProgressColumn = page.locator('[data-column="in-progress"]');

  // Verify initial state
  const card = todoColumn.getByText('Fix login bug');
  await expect(card).toBeVisible();

  const todoCountBefore = await todoColumn.getByRole('article').count();
  const inProgressCountBefore = await inProgressColumn.getByRole('article').count();

  // Drag the card to In Progress
  await card.dragTo(inProgressColumn);

  // Verify the card moved
  await expect(inProgressColumn.getByText('Fix login bug')).toBeVisible();
  await expect(todoColumn.getByText('Fix login bug')).not.toBeVisible();

  // Verify counts updated
  await expect(todoColumn.getByRole('article')).toHaveCount(todoCountBefore - 1);
  await expect(inProgressColumn.getByRole('article')).toHaveCount(inProgressCountBefore + 1);

  // Verify column header count badge updated
  await expect(todoColumn.getByText(`(${todoCountBefore - 1})`)).toBeVisible();
  await expect(inProgressColumn.getByText(`(${inProgressCountBefore + 1})`)).toBeVisible();
});

test('moves a card through all stages', async ({ page }) => {
  await page.goto('/board');

  const columns = {
    todo: page.locator('[data-column="todo"]'),
    inProgress: page.locator('[data-column="in-progress"]'),
    review: page.locator('[data-column="review"]'),
    done: page.locator('[data-column="done"]'),
  };

  // Todo -> In Progress
  await columns.todo.getByText('Fix login bug').dragTo(columns.inProgress);
  await expect(columns.inProgress.getByText('Fix login bug')).toBeVisible();

  // In Progress -> Review
  await columns.inProgress.getByText('Fix login bug').dragTo(columns.review);
  await expect(columns.review.getByText('Fix login bug')).toBeVisible();

  // Review -> Done
  await columns.review.getByText('Fix login bug').dragTo(columns.done);
  await expect(columns.done.getByText('Fix login bug')).toBeVisible();

  // Verify the card is only in the Done column
  await expect(columns.todo.getByText('Fix login bug')).not.toBeVisible();
  await expect(columns.inProgress.getByText('Fix login bug')).not.toBeVisible();
  await expect(columns.review.getByText('Fix login bug')).not.toBeVisible();
});

test('reorders cards within the same column', async ({ page }) => {
  await page.goto('/board');

  const todoColumn = page.locator('[data-column="todo"]');

  const cardA = todoColumn.getByRole('article').filter({ hasText: 'Task A' });
  const cardC = todoColumn.getByRole('article').filter({ hasText: 'Task C' });

  // Drag Task C above Task A within the same column
  await cardC.dragTo(cardA);

  // Verify new order within the column
  const cards = await todoColumn.getByRole('article').allTextContents();
  expect(cards.indexOf('Task C')).toBeLessThan(cards.indexOf('Task A'));
});

test('kanban board state persists via API', async ({ page }) => {
  await page.goto('/board');

  const todoColumn = page.locator('[data-column="todo"]');
  const inProgressColumn = page.locator('[data-column="in-progress"]');

  // Wait for the PATCH/PUT to complete after the drag
  const responsePromise = page.waitForResponse(
    (r) => r.url().includes('/api/cards') && r.request().method() === 'PATCH'
  );

  await todoColumn.getByText('Fix login bug').dragTo(inProgressColumn);

  const response = await responsePromise;
  expect(response.status()).toBe(200);

  const body = await response.json();
  expect(body.column).toBe('in-progress');

  // Reload to confirm persistence
  await page.reload();
  await expect(inProgressColumn.getByText('Fix login bug')).toBeVisible();
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('moves a card from Todo to In Progress', async ({ page }) => {
  await page.goto('/board');

  const todoColumn = page.locator('[data-column="todo"]');
  const inProgressColumn = page.locator('[data-column="in-progress"]');

  const card = todoColumn.getByText('Fix login bug');
  await expect(card).toBeVisible();

  await card.dragTo(inProgressColumn);

  await expect(inProgressColumn.getByText('Fix login bug')).toBeVisible();
  await expect(todoColumn.getByText('Fix login bug')).not.toBeVisible();
});

test('moves a card through all stages', async ({ page }) => {
  await page.goto('/board');

  const columns = {
    todo: page.locator('[data-column="todo"]'),
    inProgress: page.locator('[data-column="in-progress"]'),
    review: page.locator('[data-column="review"]'),
    done: page.locator('[data-column="done"]'),
  };

  await columns.todo.getByText('Fix login bug').dragTo(columns.inProgress);
  await expect(columns.inProgress.getByText('Fix login bug')).toBeVisible();

  await columns.inProgress.getByText('Fix login bug').dragTo(columns.review);
  await expect(columns.review.getByText('Fix login bug')).toBeVisible();

  await columns.review.getByText('Fix login bug').dragTo(columns.done);
  await expect(columns.done.getByText('Fix login bug')).toBeVisible();
});
```

---

## Recette 4 : Zone de dépôt de fichiers

> **Playwright 1.60+** : `locator.drop()` (nouveau en 1.60) simule un dépôt externe de fichiers ou de données (`{ data: { 'text/plain': ... } }`) — en dispatchant des événements `dragenter` / `dragover` / `drop` avec un `DataTransfer` synthétique. C'est l'approche à privilégier pour les zones de dépôt qui écoutent les événements `drop` (et pas seulement un `input[type=file]` caché). Sur les versions antérieures, replie-toi sur `setInputFiles` appliqué à l'input file sous-jacent (voir ci-dessous).

### Recommandé : `locator.drop()` (Playwright 1.60+)

**Quand l'utiliser** : La zone de dépôt est pilotée par des événements DOM `drop`/`dragover` (la plupart des uploaders modernes, éditeurs acceptant des images déposées, ou zones sans `input[type=file]` de repli).
**Quand l'éviter** : Tu es sur Playwright < 1.60 — utilise plutôt l'approche `setInputFiles`.

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';
import path from 'path';

test('drops a file directly onto the drop zone', async ({ page }) => {
  await page.goto('/upload');

  const dropZone = page.locator('[data-testid="file-drop-zone"]');
  await expect(dropZone).toContainText('Drag files here');

  // Drop a real file from disk — fires native dragenter/dragover/drop events
  await dropZone.drop({
    files: path.resolve(__dirname, '../fixtures/sample-document.pdf'),
  });

  await expect(page.getByText('sample-document.pdf')).toBeVisible();
});

test('drops an in-memory file buffer', async ({ page }) => {
  await page.goto('/upload');

  await page.locator('[data-testid="file-drop-zone"]').drop({
    files: {
      name: 'note.txt',
      mimeType: 'text/plain',
      buffer: Buffer.from('hello from a dropped file'),
    },
  });

  await expect(page.getByText('note.txt')).toBeVisible();
});

test('drops text/url payloads (not a file)', async ({ page }) => {
  await page.goto('/editor');

  // `data` maps MIME types to string values — great for dropped links/text
  await page.locator('#canvas').drop({
    data: {
      'text/plain': 'Hello world',
      'text/uri-list': 'https://example.com/image.png',
    },
  });

  await expect(page.getByText('https://example.com/image.png')).toBeVisible();
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');
const path = require('path');

test('drops a file directly onto the drop zone', async ({ page }) => {
  await page.goto('/upload');

  const dropZone = page.locator('[data-testid="file-drop-zone"]');
  await dropZone.drop({
    files: path.resolve(__dirname, '../fixtures/sample-document.pdf'),
  });

  await expect(page.getByText('sample-document.pdf')).toBeVisible();
});
```

### Ancienne méthode / repli : input file + événements dispatchés

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';
import path from 'path';

test('uploads a file via the underlying input (Playwright < 1.60)', async ({ page }) => {
  await page.goto('/upload');

  const dropZone = page.locator('[data-testid="file-drop-zone"]');

  // Verify initial state
  await expect(dropZone).toContainText('Drag files here');

  // On older Playwright, native OS file drops can't be simulated — drive the
  // underlying input[type=file] that most drop zones fall back to instead.
  const fileInput = page.locator('input[type="file"]');

  await fileInput.setInputFiles(path.resolve(__dirname, '../fixtures/sample-document.pdf'));

  // Verify file appears in the upload list
  await expect(page.getByText('sample-document.pdf')).toBeVisible();
  await expect(page.getByText(/\d+ KB/)).toBeVisible();
});

test('simulates drag-over visual feedback via JavaScript dispatch', async ({ page }) => {
  await page.goto('/upload');

  const dropZone = page.locator('[data-testid="file-drop-zone"]');

  // Dispatch dragenter/dragover events to test visual feedback
  await dropZone.dispatchEvent('dragenter', {
    dataTransfer: { types: ['Files'] },
  });

  // Verify the drop zone shows the active/hover state
  await expect(dropZone).toHaveClass(/drag-active|drop-highlight/);
  await expect(dropZone).toContainText(/drop.*here|release.*upload/i);

  // Dispatch dragleave to reset
  await dropZone.dispatchEvent('dragleave');

  await expect(dropZone).not.toHaveClass(/drag-active|drop-highlight/);
});

test('rejects invalid file types in drop zone', async ({ page }) => {
  await page.goto('/upload');

  const fileInput = page.locator('input[type="file"]');

  // Try to upload a file type that is not allowed
  await fileInput.setInputFiles({
    name: 'malware.exe',
    mimeType: 'application/x-msdownload',
    buffer: Buffer.from('fake-content'),
  });

  await expect(page.getByRole('alert')).toContainText(/not allowed|invalid file type/i);
  await expect(page.getByText('malware.exe')).not.toBeVisible();
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');
const path = require('path');

test('uploads a file by dropping it on the drop zone', async ({ page }) => {
  await page.goto('/upload');

  const dropZone = page.locator('[data-testid="file-drop-zone"]');
  await expect(dropZone).toContainText('Drag files here');

  const fileInput = page.locator('input[type="file"]');
  await fileInput.setInputFiles(path.resolve(__dirname, '../fixtures/sample-document.pdf'));

  await expect(page.getByText('sample-document.pdf')).toBeVisible();
});

test('rejects invalid file types in drop zone', async ({ page }) => {
  await page.goto('/upload');

  const fileInput = page.locator('input[type="file"]');

  await fileInput.setInputFiles({
    name: 'malware.exe',
    mimeType: 'application/x-msdownload',
    buffer: Buffer.from('fake-content'),
  });

  await expect(page.getByRole('alert')).toContainText(/not allowed|invalid file type/i);
});
```

---

## Recette 5 : Drag avec aperçu personnalisé / image fantôme

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('shows custom drag preview during drag operation', async ({ page }) => {
  await page.goto('/board');

  const card = page.locator('[data-testid="card-1"]');
  const targetColumn = page.locator('[data-column="in-progress"]');

  const cardBox = await card.boundingBox();
  const targetBox = await targetColumn.boundingBox();

  // Start dragging
  await card.hover();
  await page.mouse.down();

  // Move partially toward the target
  const midX = (cardBox!.x + targetBox!.x) / 2;
  const midY = (cardBox!.y + targetBox!.y) / 2;
  await page.mouse.move(midX, midY, { steps: 5 });

  // Take a screenshot to visually verify the drag preview
  // The custom preview element should be visible during drag
  await expect(page.locator('.drag-preview')).toBeVisible();

  // Verify the original card shows a placeholder/ghost
  await expect(card).toHaveClass(/dragging|placeholder/);

  // Complete the drag
  await page.mouse.move(
    targetBox!.x + targetBox!.width / 2,
    targetBox!.y + targetBox!.height / 2,
    { steps: 5 }
  );
  await page.mouse.up();

  // Preview should disappear after drop
  await expect(page.locator('.drag-preview')).not.toBeVisible();
});

test('drag preview shows item count for multi-select drag', async ({ page }) => {
  await page.goto('/board');

  // Select multiple cards
  await page.locator('[data-testid="card-1"]').click();
  await page.locator('[data-testid="card-2"]').click({ modifiers: ['Shift'] });
  await page.locator('[data-testid="card-3"]').click({ modifiers: ['Shift'] });

  // Start dragging one of the selected cards
  const card = page.locator('[data-testid="card-1"]');
  const targetColumn = page.locator('[data-column="done"]');

  await card.hover();
  await page.mouse.down();

  const targetBox = await targetColumn.boundingBox();
  await page.mouse.move(targetBox!.x + 50, targetBox!.y + 50, { steps: 5 });

  // Verify the preview shows the count of selected items
  await expect(page.locator('.drag-preview')).toContainText('3 items');

  await page.mouse.up();

  // All three cards should be in the target column
  await expect(targetColumn.locator('[data-testid="card-1"]')).toBeVisible();
  await expect(targetColumn.locator('[data-testid="card-2"]')).toBeVisible();
  await expect(targetColumn.locator('[data-testid="card-3"]')).toBeVisible();
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('shows custom drag preview during drag operation', async ({ page }) => {
  await page.goto('/board');

  const card = page.locator('[data-testid="card-1"]');
  const targetColumn = page.locator('[data-column="in-progress"]');

  const cardBox = await card.boundingBox();
  const targetBox = await targetColumn.boundingBox();

  await card.hover();
  await page.mouse.down();

  const midX = (cardBox.x + targetBox.x) / 2;
  const midY = (cardBox.y + targetBox.y) / 2;
  await page.mouse.move(midX, midY, { steps: 5 });

  await expect(page.locator('.drag-preview')).toBeVisible();
  await expect(card).toHaveClass(/dragging|placeholder/);

  await page.mouse.move(
    targetBox.x + targetBox.width / 2,
    targetBox.y + targetBox.height / 2,
    { steps: 5 }
  );
  await page.mouse.up();

  await expect(page.locator('.drag-preview')).not.toBeVisible();
});
```

---

## Recette 6 : Tester la position et les coordonnées du drag

### Exemple complet

**TypeScript**

```typescript
import { test, expect } from '@playwright/test';

test('drags an element to a specific coordinate on a canvas', async ({ page }) => {
  await page.goto('/canvas-editor');

  const canvas = page.locator('#design-canvas');
  const element = page.locator('[data-testid="shape-1"]');

  // Get the initial position
  const initialBox = await element.boundingBox();
  expect(initialBox).toBeTruthy();

  // Define target position (absolute coordinates within the canvas)
  const canvasBox = await canvas.boundingBox();
  const targetX = canvasBox!.x + 300;
  const targetY = canvasBox!.y + 200;

  // Drag to specific coordinates
  await element.hover();
  await page.mouse.down();
  await page.mouse.move(targetX, targetY, { steps: 10 });
  await page.mouse.up();

  // Verify element moved to approximately the right position
  const newBox = await element.boundingBox();
  expect(newBox!.x).toBeCloseTo(targetX - newBox!.width / 2, -1);
  expect(newBox!.y).toBeCloseTo(targetY - newBox!.height / 2, -1);
});

test('snaps element to grid when dropped', async ({ page }) => {
  await page.goto('/canvas-editor');

  const element = page.locator('[data-testid="shape-1"]');
  const canvas = page.locator('#design-canvas');

  const canvasBox = await canvas.boundingBox();

  // Drag to a position that is not on the grid
  await element.hover();
  await page.mouse.down();
  await page.mouse.move(canvasBox!.x + 147, canvasBox!.y + 83, { steps: 10 });
  await page.mouse.up();

  // With a 20px grid, position should snap to nearest grid point
  const snappedBox = await element.boundingBox();
  expect(snappedBox!.x % 20).toBeCloseTo(0, 0);
  expect(snappedBox!.y % 20).toBeCloseTo(0, 0);
});

test('constrains drag within boundaries', async ({ page }) => {
  await page.goto('/canvas-editor');

  const element = page.locator('[data-testid="constrained-element"]');
  const container = page.locator('#constraint-box');

  const containerBox = await container.boundingBox();

  // Try to drag far outside the container
  await element.hover();
  await page.mouse.down();
  await page.mouse.move(containerBox!.x + containerBox!.width + 500, containerBox!.y - 200, {
    steps: 10,
  });
  await page.mouse.up();

  // Element should be clamped within the container
  const elementBox = await element.boundingBox();

  expect(elementBox!.x).toBeGreaterThanOrEqual(containerBox!.x);
  expect(elementBox!.y).toBeGreaterThanOrEqual(containerBox!.y);
  expect(elementBox!.x + elementBox!.width).toBeLessThanOrEqual(
    containerBox!.x + containerBox!.width
  );
  expect(elementBox!.y + elementBox!.height).toBeLessThanOrEqual(
    containerBox!.y + containerBox!.height
  );
});

test('resizes an element by dragging its handle', async ({ page }) => {
  await page.goto('/canvas-editor');

  const element = page.locator('[data-testid="shape-1"]');
  await element.click(); // Select to show resize handles

  const resizeHandle = element.locator('.resize-handle-se'); // south-east corner
  const handleBox = await resizeHandle.boundingBox();

  const initialBox = await element.boundingBox();

  // Drag the resize handle to make the element larger
  await resizeHandle.hover();
  await page.mouse.down();
  await page.mouse.move(handleBox!.x + 100, handleBox!.y + 80, { steps: 5 });
  await page.mouse.up();

  const newBox = await element.boundingBox();
  expect(newBox!.width).toBeCloseTo(initialBox!.width + 100, -1);
  expect(newBox!.height).toBeCloseTo(initialBox!.height + 80, -1);
});
```

**JavaScript**

```javascript
const { test, expect } = require('@playwright/test');

test('drags an element to a specific coordinate on a canvas', async ({ page }) => {
  await page.goto('/canvas-editor');

  const canvas = page.locator('#design-canvas');
  const element = page.locator('[data-testid="shape-1"]');

  const canvasBox = await canvas.boundingBox();
  const targetX = canvasBox.x + 300;
  const targetY = canvasBox.y + 200;

  await element.hover();
  await page.mouse.down();
  await page.mouse.move(targetX, targetY, { steps: 10 });
  await page.mouse.up();

  const newBox = await element.boundingBox();
  expect(newBox.x).toBeCloseTo(targetX - newBox.width / 2, -1);
  expect(newBox.y).toBeCloseTo(targetY - newBox.height / 2, -1);
});

test('constrains drag within boundaries', async ({ page }) => {
  await page.goto('/canvas-editor');

  const element = page.locator('[data-testid="constrained-element"]');
  const container = page.locator('#constraint-box');

  const containerBox = await container.boundingBox();

  await element.hover();
  await page.mouse.down();
  await page.mouse.move(containerBox.x + containerBox.width + 500, containerBox.y - 200, {
    steps: 10,
  });
  await page.mouse.up();

  const elementBox = await element.boundingBox();
  expect(elementBox.x).toBeGreaterThanOrEqual(containerBox.x);
  expect(elementBox.y).toBeGreaterThanOrEqual(containerBox.y);
});
```

---

## Variantes

### Drag and drop avec accessibilité au clavier

```typescript
test('reorders items using keyboard', async ({ page }) => {
  await page.goto('/tasks');

  const list = page.getByRole('list', { name: 'Task list' });
  const taskC = list.getByRole('listitem').filter({ hasText: 'Task C' });

  // Focus the item
  await taskC.focus();

  // Use keyboard shortcut to pick up the item
  await page.keyboard.press('Space');

  // Move up twice
  await page.keyboard.press('ArrowUp');
  await page.keyboard.press('ArrowUp');

  // Drop the item
  await page.keyboard.press('Space');

  const items = await list.getByRole('listitem').allTextContents();
  expect(items[0]).toContain('Task C');
});
```

### Drag and drop entre iframes

```typescript
test('drags between main page and iframe', async ({ page }) => {
  await page.goto('/editor');

  const sourceItem = page.getByText('Widget A');
  const iframe = page.frameLocator('#preview-frame');
  const dropTarget = iframe.locator('#content-area');

  // Cross-frame drag requires coordinates since dragTo does not work across frames
  const sourceBox = await sourceItem.boundingBox();
  const iframeElement = page.locator('#preview-frame');
  const iframeBox = await iframeElement.boundingBox();

  // Calculate target position within the iframe
  const targetX = iframeBox!.x + 100;
  const targetY = iframeBox!.y + 100;

  await sourceItem.hover();
  await page.mouse.down();
  await page.mouse.move(targetX, targetY, { steps: 20 });
  await page.mouse.up();

  await expect(iframe.getByText('Widget A')).toBeVisible();
});
```

### Drag tactile sur mobile

```typescript
test('drags items on mobile via touch events', async ({ page }) => {
  await page.goto('/tasks');

  const list = page.getByRole('list', { name: 'Task list' });
  const sourceItem = list.getByRole('listitem').filter({ hasText: 'Task C' });
  const targetItem = list.getByRole('listitem').filter({ hasText: 'Task A' });

  const sourceBox = await sourceItem.boundingBox();
  const targetBox = await targetItem.boundingBox();

  // Simulate long-press then drag using touch
  await page.touchscreen.tap(sourceBox!.x + sourceBox!.width / 2, sourceBox!.y + sourceBox!.height / 2);

  // Dispatch touchstart, touchmove, touchend for libraries that use touch events
  await sourceItem.dispatchEvent('touchstart', {
    touches: [{ clientX: sourceBox!.x + 10, clientY: sourceBox!.y + 10 }],
  });

  // Move in steps
  for (let i = 1; i <= 5; i++) {
    const y = sourceBox!.y + (targetBox!.y - sourceBox!.y) * (i / 5);
    await sourceItem.dispatchEvent('touchmove', {
      touches: [{ clientX: sourceBox!.x + 10, clientY: y }],
    });
  }

  await sourceItem.dispatchEvent('touchend');

  const items = await list.getByRole('listitem').allTextContents();
  expect(items[0]).toContain('Task C');
});
```

---

## Conseils

1. **Utilise `dragTo()` d'abord, puis replie-toi sur les événements souris manuels**. Le `dragTo()` intégré de Playwright gère la plupart des drag and drop HTML5 natifs. N'utilise les séquences `page.mouse.down()` / `move()` / `up()` que pour les bibliothèques de drag personnalisées (react-beautiful-dnd, dnd-kit, SortableJS) qui exigent des séquences d'événements précises.

2. **Ajoute des étapes intermédiaires de déplacement souris pour les bibliothèques de drag**. Des bibliothèques comme `react-beautiful-dnd` exigent plusieurs événements `mousemove` à petits incréments pour détecter un drag. Utilise `{ steps: 10 }` ou une boucle manuelle. Un seul saut de la source à la cible échoue souvent silencieusement.

3. **Fais toujours l'assertion sur l'état final, pas seulement sur l'événement de drop**. Après un drag and drop, vérifie que le DOM reflète réellement le changement -- ordre des éléments, contenu des colonnes, coordonnées de position. Le feedback visuel pendant le drag est intéressant à tester, mais l'état final persisté compte le plus.

4. **Utilise `boundingBox()` pour les assertions basées sur les coordonnées**. Pour tester des éditeurs canvas, des layouts en grille ou des drops sensibles à la position, capture la bounding box après l'opération et compare-la aux coordonnées attendues. Utilise `toBeCloseTo()` pour la tolérance.

5. **Teste l'annulation (undo) après les opérations de drag**. Si ton application supporte Ctrl+Z pour annuler un réordonnancement ou un déplacement, teste que l'opération de drag est réversible. Cela détecte des bugs de gestion d'état qui n'apparaissent qu'à l'annulation.

---

## Voir aussi

- [Documentation Playwright sur le drag and drop](https://playwright.dev/docs/input#drag-and-drop)
- `recipes/file-upload-download.md` -- Zones de dépôt de fichiers en particulier
- `foundations/actions.md` -- Bases des interactions souris et clavier
- `patterns/page-objects.md` -- Encapsuler les flux de drag complexes
