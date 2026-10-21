# Opérations sur les fichiers

> **Quand l'utiliser** : tester les uploads, les téléchargements, les interactions de drag-and-drop de fichiers, la validation des types de fichiers et la vérification des téléchargements.
> **Prérequis** : [core/locators.md](locators.md), [core/assertions-and-waiting.md](assertions-and-waiting.md)

## Référence rapide

```typescript
// Upload — single file
await page.getByLabel('Upload').setInputFiles('fixtures/resume.pdf');

// Upload — multiple files
await page.getByLabel('Upload').setInputFiles(['fixtures/a.png', 'fixtures/b.png']);

// Upload — clear selection
await page.getByLabel('Upload').setInputFiles([]);

// Download — wait and save
const download = await page.waitForEvent('download');
await page.getByRole('button', { name: 'Export CSV' }).click();
const path = await download.path();           // temp path
await download.saveAs('test-results/export.csv'); // permanent path

// File chooser dialog — non-input uploads
const fileChooser = await page.waitForEvent('filechooser');
await page.getByRole('button', { name: 'Choose file' }).click();
await fileChooser.setFiles('fixtures/photo.jpg');
```

## Patterns

### Upload d'un seul fichier

**À utiliser quand** : un formulaire contient un élément `<input type="file">` standard.
**À éviter quand** : l'upload passe par une zone de drag-and-drop sans `input` de fichier sous-jacent.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import path from 'path';

test('upload a single document', async ({ page }) => {
  await page.goto('/settings/profile');

  const filePath = path.join(__dirname, '../fixtures/avatar.png');
  await page.getByLabel('Profile picture').setInputFiles(filePath);

  // Verify the file name appears in the UI
  await expect(page.getByText('avatar.png')).toBeVisible();

  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('Profile updated')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const path = require('path');

test('upload a single document', async ({ page }) => {
  await page.goto('/settings/profile');

  const filePath = path.join(__dirname, '../fixtures/avatar.png');
  await page.getByLabel('Profile picture').setInputFiles(filePath);

  await expect(page.getByText('avatar.png')).toBeVisible();

  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page.getByText('Profile updated')).toBeVisible();
});
```

### Upload de plusieurs fichiers

**À utiliser quand** : l'`input` de fichier accepte `multiple` et que tu dois joindre plusieurs fichiers d'un coup.
**À éviter quand** : l'UI n'autorise qu'un seul fichier. Utilise alors l'upload d'un seul fichier.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import path from 'path';

test('upload multiple attachments', async ({ page }) => {
  await page.goto('/tickets/new');

  const fixtures = ['doc1.pdf', 'doc2.pdf', 'screenshot.png'].map(
    (f) => path.join(__dirname, '../fixtures', f)
  );

  await page.getByLabel('Attachments').setInputFiles(fixtures);

  // Verify all files are listed
  await expect(page.getByTestId('file-list').getByRole('listitem')).toHaveCount(3);

  // Remove one file by clearing and re-setting
  await page.getByLabel('Attachments').setInputFiles(fixtures.slice(0, 2));
  await expect(page.getByTestId('file-list').getByRole('listitem')).toHaveCount(2);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const path = require('path');

test('upload multiple attachments', async ({ page }) => {
  await page.goto('/tickets/new');

  const fixtures = ['doc1.pdf', 'doc2.pdf', 'screenshot.png'].map(
    (f) => path.join(__dirname, '../fixtures', f)
  );

  await page.getByLabel('Attachments').setInputFiles(fixtures);
  await expect(page.getByTestId('file-list').getByRole('listitem')).toHaveCount(3);

  await page.getByLabel('Attachments').setInputFiles(fixtures.slice(0, 2));
  await expect(page.getByTestId('file-list').getByRole('listitem')).toHaveCount(2);
});
```

### Boîte de dialogue du sélecteur de fichiers (File Chooser)

**À utiliser quand** : l'upload est déclenché par un clic sur un bouton qui ouvre le sélecteur de fichiers natif, et non par un `<input type="file">` visible. Fréquent avec les bibliothèques de drag-and-drop et les composants d'upload personnalisés.
**À éviter quand** : il existe un `<input type="file">` visible — utilise directement `setInputFiles`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('upload via file chooser dialog', async ({ page }) => {
  await page.goto('/documents');

  // Register the listener BEFORE the click that opens the dialog
  const fileChooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Upload document' }).click();
  const fileChooser = await fileChooserPromise;

  // Verify dialog properties
  expect(fileChooser.isMultiple()).toBe(false);

  await fileChooser.setFiles('fixtures/report.pdf');
  await expect(page.getByText('report.pdf')).toBeVisible();
});

test('upload multiple via file chooser', async ({ page }) => {
  await page.goto('/gallery');

  const fileChooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Add photos' }).click();
  const fileChooser = await fileChooserPromise;

  expect(fileChooser.isMultiple()).toBe(true);
  await fileChooser.setFiles(['fixtures/photo1.jpg', 'fixtures/photo2.jpg']);

  await expect(page.getByRole('img')).toHaveCount(2);
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('upload via file chooser dialog', async ({ page }) => {
  await page.goto('/documents');

  const fileChooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Upload document' }).click();
  const fileChooser = await fileChooserPromise;

  expect(fileChooser.isMultiple()).toBe(false);

  await fileChooser.setFiles('fixtures/report.pdf');
  await expect(page.getByText('report.pdf')).toBeVisible();
});

test('upload multiple via file chooser', async ({ page }) => {
  await page.goto('/gallery');

  const fileChooserPromise = page.waitForEvent('filechooser');
  await page.getByRole('button', { name: 'Add photos' }).click();
  const fileChooser = await fileChooserPromise;

  expect(fileChooser.isMultiple()).toBe(true);
  await fileChooser.setFiles(['fixtures/photo1.jpg', 'fixtures/photo2.jpg']);

  await expect(page.getByRole('img')).toHaveCount(2);
});
```

### Upload de fichier par drag-and-drop

**À utiliser quand** : l'UI a une zone de dépôt qui accepte des fichiers via l'API HTML5 Drag and Drop et n'a aucun `<input type="file">` de secours.
**À éviter quand** : un `input` de fichier existe — même masqué, il fonctionne avec `setInputFiles`.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import fs from 'fs';
import path from 'path';

test('drop file onto upload zone', async ({ page }) => {
  await page.goto('/upload');

  // Read the file into a buffer
  const filePath = path.join(__dirname, '../fixtures/data.csv');
  const buffer = fs.readFileSync(filePath);

  // Create a DataTransfer with the file and dispatch drop event
  const dropZone = page.getByTestId('drop-zone');

  await dropZone.dispatchEvent('drop', {
    dataTransfer: {
      files: [
        { name: 'data.csv', mimeType: 'text/csv', buffer },
      ],
    },
  });

  await expect(page.getByText('data.csv')).toBeVisible();
  await expect(page.getByText('Upload complete')).toBeVisible();
});

test('drag-and-drop with hidden input fallback', async ({ page }) => {
  await page.goto('/upload');

  // Many drag-and-drop libraries still use a hidden <input type="file">
  // Check for it first — this is more reliable than simulating DnD events
  const hiddenInput = page.locator('input[type="file"]');

  if (await hiddenInput.count() > 0) {
    await hiddenInput.setInputFiles('fixtures/data.csv');
  }

  await expect(page.getByText('data.csv')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

test('drop file onto upload zone', async ({ page }) => {
  await page.goto('/upload');

  const filePath = path.join(__dirname, '../fixtures/data.csv');
  const buffer = fs.readFileSync(filePath);

  const dropZone = page.getByTestId('drop-zone');

  await dropZone.dispatchEvent('drop', {
    dataTransfer: {
      files: [
        { name: 'data.csv', mimeType: 'text/csv', buffer },
      ],
    },
  });

  await expect(page.getByText('data.csv')).toBeVisible();
  await expect(page.getByText('Upload complete')).toBeVisible();
});

test('drag-and-drop with hidden input fallback', async ({ page }) => {
  await page.goto('/upload');

  const hiddenInput = page.locator('input[type="file"]');

  if (await hiddenInput.count() > 0) {
    await hiddenInput.setInputFiles('fixtures/data.csv');
  }

  await expect(page.getByText('data.csv')).toBeVisible();
});
```

### Téléchargement de fichier — attendre et vérifier

**À utiliser quand** : tu testes des boutons d'export, la génération de rapports, ou toute action qui déclenche un téléchargement du navigateur.
**À éviter quand** : le fichier est servi comme une navigation de page (ouverture dans un nouvel onglet). Utilise alors les patterns multi-onglets.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import fs from 'fs';

test('download and verify file content', async ({ page }) => {
  await page.goto('/reports');

  // Register BEFORE the click that triggers the download
  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export CSV' }).click();
  const download = await downloadPromise;

  // Verify download metadata
  expect(download.suggestedFilename()).toBe('report-2025.csv');

  // Save to a known location
  const savePath = 'test-results/report.csv';
  await download.saveAs(savePath);

  // Read and verify content
  const content = fs.readFileSync(savePath, 'utf-8');
  expect(content).toContain('Name,Email,Status');
  expect(content).toContain('Jane Doe,jane@example.com,Active');

  // Verify file size is reasonable
  const stats = fs.statSync(savePath);
  expect(stats.size).toBeGreaterThan(100);
});

test('download triggered by a link', async ({ page }) => {
  await page.goto('/files');

  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('link', { name: 'Download invoice' }).click();
  const download = await downloadPromise;

  expect(download.suggestedFilename()).toMatch(/invoice-\d+\.pdf/);

  // Use download.path() for the temp file path
  const tempPath = await download.path();
  expect(tempPath).toBeTruthy();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const fs = require('fs');

test('download and verify file content', async ({ page }) => {
  await page.goto('/reports');

  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export CSV' }).click();
  const download = await downloadPromise;

  expect(download.suggestedFilename()).toBe('report-2025.csv');

  const savePath = 'test-results/report.csv';
  await download.saveAs(savePath);

  const content = fs.readFileSync(savePath, 'utf-8');
  expect(content).toContain('Name,Email,Status');
  expect(content).toContain('Jane Doe,jane@example.com,Active');

  const stats = fs.statSync(savePath);
  expect(stats.size).toBeGreaterThan(100);
});

test('download triggered by a link', async ({ page }) => {
  await page.goto('/files');

  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('link', { name: 'Download invoice' }).click();
  const download = await downloadPromise;

  expect(download.suggestedFilename()).toMatch(/invoice-\d+\.pdf/);

  const tempPath = await download.path();
  expect(tempPath).toBeTruthy();
});
```

### Configurer les chemins de téléchargement

**À utiliser quand** : tu veux que les téléchargements aillent dans un répertoire précis, ou désactiver la boîte de dialogue de téléchargement.
**À éviter quand** : les chemins temporaires par défaut via `download.path()` ou `download.saveAs()` suffisent.

**TypeScript**
```typescript
// playwright.config.ts — global download behavior
import { defineConfig } from '@playwright/test';

export default defineConfig({
  use: {
    // Accept all downloads without prompting
    acceptDownloads: true, // default is true
  },
});
```

```typescript
import { test, expect } from '@playwright/test';
import fs from 'fs';
import path from 'path';

// Per-test download directory via a custom fixture
const downloadTest = test.extend<{ downloadDir: string }>({
  downloadDir: async ({}, use, testInfo) => {
    const dir = path.join('test-results', 'downloads', testInfo.title.replace(/\s+/g, '-'));
    fs.mkdirSync(dir, { recursive: true });
    await use(dir);
  },
});

downloadTest('save downloads to organized directories', async ({ page, downloadDir }) => {
  await page.goto('/exports');

  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export' }).click();
  const download = await downloadPromise;

  const savePath = path.join(downloadDir, download.suggestedFilename());
  await download.saveAs(savePath);

  expect(fs.existsSync(savePath)).toBe(true);
});
```

**JavaScript**
```javascript
// playwright.config.js
const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  use: {
    acceptDownloads: true,
  },
});
```

```javascript
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const downloadTest = test.extend({
  downloadDir: async ({}, use, testInfo) => {
    const dir = path.join('test-results', 'downloads', testInfo.title.replace(/\s+/g, '-'));
    fs.mkdirSync(dir, { recursive: true });
    await use(dir);
  },
});

downloadTest('save downloads to organized directories', async ({ page, downloadDir }) => {
  await page.goto('/exports');

  const downloadPromise = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Export' }).click();
  const download = await downloadPromise;

  const savePath = path.join(downloadDir, download.suggestedFilename());
  await download.saveAs(savePath);

  expect(fs.existsSync(savePath)).toBe(true);
});
```

### Validation du type de fichier

**À utiliser quand** : tu vérifies que l'application rejette les types de fichiers invalides et accepte les valides.
**À éviter quand** : l'application ne fait aucune validation côté client et s'appuie uniquement sur des contrôles côté serveur (teste alors via l'API).

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';

test('rejects unsupported file types', async ({ page }) => {
  await page.goto('/upload');

  // Upload an invalid file type
  await page.getByLabel('Upload image').setInputFiles({
    name: 'malware.exe',
    mimeType: 'application/octet-stream',
    buffer: Buffer.from('fake-exe-content'),
  });

  await expect(page.getByText('Only JPG, PNG, and GIF files are allowed')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Submit' })).toBeDisabled();
});

test('accepts valid file types', async ({ page }) => {
  await page.goto('/upload');

  await page.getByLabel('Upload image').setInputFiles({
    name: 'photo.jpg',
    mimeType: 'image/jpeg',
    buffer: Buffer.from('fake-jpg-content'),
  });

  await expect(page.getByText('photo.jpg')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled();
});

test('validates file size limits', async ({ page }) => {
  await page.goto('/upload');

  // Create a buffer that exceeds the 5MB limit
  const largeBuffer = Buffer.alloc(6 * 1024 * 1024, 'x');

  await page.getByLabel('Upload document').setInputFiles({
    name: 'huge-file.pdf',
    mimeType: 'application/pdf',
    buffer: largeBuffer,
  });

  await expect(page.getByText('File size must be under 5MB')).toBeVisible();
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');

test('rejects unsupported file types', async ({ page }) => {
  await page.goto('/upload');

  await page.getByLabel('Upload image').setInputFiles({
    name: 'malware.exe',
    mimeType: 'application/octet-stream',
    buffer: Buffer.from('fake-exe-content'),
  });

  await expect(page.getByText('Only JPG, PNG, and GIF files are allowed')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Submit' })).toBeDisabled();
});

test('accepts valid file types', async ({ page }) => {
  await page.goto('/upload');

  await page.getByLabel('Upload image').setInputFiles({
    name: 'photo.jpg',
    mimeType: 'image/jpeg',
    buffer: Buffer.from('fake-jpg-content'),
  });

  await expect(page.getByText('photo.jpg')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled();
});

test('validates file size limits', async ({ page }) => {
  await page.goto('/upload');

  const largeBuffer = Buffer.alloc(6 * 1024 * 1024, 'x');

  await page.getByLabel('Upload document').setInputFiles({
    name: 'huge-file.pdf',
    mimeType: 'application/pdf',
    buffer: largeBuffer,
  });

  await expect(page.getByText('File size must be under 5MB')).toBeVisible();
});
```

### Gestion des gros fichiers

**À utiliser quand** : tu testes l'upload ou le téléchargement de gros fichiers, là où les timeouts et les indicateurs de progression comptent.
**À éviter quand** : dans chaque test. Les tests de gros fichiers sont lents. Lance-les dans une suite séparée ou tague-les pour des exécutions nocturnes.

**TypeScript**
```typescript
import { test, expect } from '@playwright/test';
import fs from 'fs';
import path from 'path';

test.describe('large file operations', () => {
  // Increase timeout for the entire describe block
  test.slow(); // Triples the default timeout

  test('upload large file with progress tracking', async ({ page }) => {
    await page.goto('/upload');

    // Create a test file on disk (avoid Buffer.alloc for very large files)
    const largePath = path.join('test-results', 'large-test-file.bin');
    const stream = fs.createWriteStream(largePath);
    for (let i = 0; i < 100; i++) {
      stream.write(Buffer.alloc(1024 * 1024, 'a')); // 100MB total
    }
    stream.end();
    await new Promise((resolve) => stream.on('finish', resolve));

    await page.getByLabel('Upload file').setInputFiles(largePath);

    // Wait for progress indicator
    await expect(page.getByRole('progressbar')).toBeVisible();

    // Wait for completion — extended timeout
    await expect(page.getByText('Upload complete')).toBeVisible({ timeout: 120_000 });

    // Cleanup
    fs.unlinkSync(largePath);
  });

  test('download large file', async ({ page }) => {
    await page.goto('/exports');

    const downloadPromise = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Export full dataset' }).click();
    const download = await downloadPromise;

    const savePath = 'test-results/large-export.zip';
    await download.saveAs(savePath);

    // Verify file size is reasonable (at least 10MB)
    const stats = fs.statSync(savePath);
    expect(stats.size).toBeGreaterThan(10 * 1024 * 1024);

    fs.unlinkSync(savePath);
  });
});
```

**JavaScript**
```javascript
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

test.describe('large file operations', () => {
  test.slow();

  test('upload large file with progress tracking', async ({ page }) => {
    await page.goto('/upload');

    const largePath = path.join('test-results', 'large-test-file.bin');
    const stream = fs.createWriteStream(largePath);
    for (let i = 0; i < 100; i++) {
      stream.write(Buffer.alloc(1024 * 1024, 'a'));
    }
    stream.end();
    await new Promise((resolve) => stream.on('finish', resolve));

    await page.getByLabel('Upload file').setInputFiles(largePath);

    await expect(page.getByRole('progressbar')).toBeVisible();
    await expect(page.getByText('Upload complete')).toBeVisible({ timeout: 120_000 });

    fs.unlinkSync(largePath);
  });

  test('download large file', async ({ page }) => {
    await page.goto('/exports');

    const downloadPromise = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Export full dataset' }).click();
    const download = await downloadPromise;

    const savePath = 'test-results/large-export.zip';
    await download.saveAs(savePath);

    const stats = fs.statSync(savePath);
    expect(stats.size).toBeGreaterThan(10 * 1024 * 1024);

    fs.unlinkSync(savePath);
  });
});
```

## Guide de décision

| Scénario | Approche | API clé |
|---|---|---|
| `<input type="file">` standard | `setInputFiles()` sur le locator | `locator.setInputFiles(path)` |
| `input` de fichier masqué | Trouve l'`input` même masqué, appelle `setInputFiles()` | `page.locator('input[type="file"]').setInputFiles()` |
| Un bouton personnalisé ouvre le sélecteur de fichiers | Écoute l'événement `filechooser` avant de cliquer | `page.waitForEvent('filechooser')` |
| Zone de drag-and-drop sans `input` | Déclenche l'événement `drop` avec un `DataTransfer` | `locator.dispatchEvent('drop', ...)` |
| Zone DnD avec `input` masqué de secours | Préfère `setInputFiles()` sur l'`input` masqué | Vérifie d'abord le nombre de `input[type="file"]` |
| Plusieurs fichiers d'un coup | Passe un tableau à `setInputFiles()` | `setInputFiles([path1, path2])` |
| Fichier de test en mémoire (sans disque) | Passe un objet avec `name`, `mimeType`, `buffer` | `setInputFiles({ name, mimeType, buffer })` |
| Téléchargement — vérifier le nom | `download.suggestedFilename()` | `page.waitForEvent('download')` |
| Téléchargement — vérifier le contenu | `download.saveAs()` puis lecture avec `fs` | `fs.readFileSync()` |
| Téléchargement — fichier temporaire uniquement | `download.path()` renvoie l'emplacement temporaire | Supprimé automatiquement après le test |
| Upload/téléchargement de gros fichier | Utilise `test.slow()`, augmente les timeouts des assertions | `{ timeout: 120_000 }` |

## Anti-patterns

| À ne pas faire | Problème | À faire à la place |
|---|---|---|
| `await page.waitForTimeout(3000)` après un upload | Délai arbitraire ; flaky | `await expect(page.getByText('Upload complete')).toBeVisible()` |
| `await page.setInputFiles('#file', path)` avec un sélecteur CSS | Sélecteur fragile ; casse si l'ID change | `await page.getByLabel('Upload').setInputFiles(path)` |
| Cliquer sur le téléchargement puis lire immédiatement le fichier | Race condition ; le fichier n'est peut-être pas encore écrit | Utilise `page.waitForEvent('download')` puis `download.saveAs()` |
| Créer de gros fichiers de test dans `beforeAll` sans jamais les nettoyer | Remplit le disque en CI, ralentit les exécutions suivantes | Nettoie dans `afterAll` ou via le teardown d'une fixture |
| Utiliser `page.on('filechooser')` pour chaque upload | Complexité inutile quand un `<input type="file">` existe | Utilise directement `setInputFiles()` |
| Coder en dur des chemins de fichiers absolus | Casse d'une machine à l'autre et en CI | Utilise `path.join(__dirname, ...)` ou un chemin relatif à la racine du projet |
| Tester l'upload avec un buffer vide | Ne teste pas le vrai comportement de validation | Utilise un contenu de fichier réaliste ou une taille minimale valide |
| Utiliser `download.path()` pour un stockage permanent | Les fichiers temporaires sont nettoyés à la fermeture du contexte de test | Utilise `download.saveAs()` pour les chemins permanents |
| Uploader de vrais fichiers de 100 Mo à chaque exécution | Ralentit toute la suite, gaspille les ressources de CI | Tague les tests de gros fichiers à part ; lance-les de façon planifiée, pas à chaque PR |

## Dépannage

### « FileChooser event was not emitted »

**Cause** : le clic n'a pas ouvert de sélecteur de fichiers natif. Le composant d'upload utilise peut-être un autre mécanisme.

```typescript
// Debug: check if there is a hidden <input type="file"> you can target directly
const fileInputCount = await page.locator('input[type="file"]').count();
console.log(`Found ${fileInputCount} file inputs`);

// If input exists, skip the file chooser approach entirely
if (fileInputCount > 0) {
  await page.locator('input[type="file"]').setInputFiles('fixtures/file.pdf');
}
```

### « Download event was not emitted »

**Cause** : le lien s'ouvre dans un nouvel onglet ou navigue vers l'URL du fichier au lieu de déclencher un téléchargement.

```typescript
// Fix 1: Ensure acceptDownloads is true in config
// Fix 2: Check if the link opens a new tab — handle it as a new page
const pagePromise = page.context().waitForEvent('page');
await page.getByRole('link', { name: 'Download' }).click();
const newPage = await pagePromise;
// Then wait for the download event on the new page
const download = await newPage.waitForEvent('download');
```

### L'upload fonctionne en local mais échoue en CI

**Cause** : les chemins de fichiers sont incorrects en CI, ou les fichiers de fixture ne sont pas inclus dans le dépôt/le build.

```typescript
// Fix: always resolve paths relative to the test file
import path from 'path';
const fixturePath = path.join(__dirname, '..', 'fixtures', 'test-file.pdf');

// Verify the file exists before uploading
import fs from 'fs';
if (!fs.existsSync(fixturePath)) {
  throw new Error(`Fixture file missing: ${fixturePath}`);
}
```

### `setInputFiles` ne fait rien — aucun fichier n'apparaît

**Cause** : l'élément `input` est détaché, dans un Shadow DOM ou dans une iframe.

```typescript
// Check for iframe
const frame = page.frameLocator('iframe[title="Upload"]');
await frame.locator('input[type="file"]').setInputFiles('fixtures/file.pdf');

// Check for Shadow DOM — Playwright pierces open shadow roots automatically
// but the input may be in a closed shadow root (rare). Use the file chooser approach instead.
```

## Voir aussi

- [core/locators.md](locators.md) -- stratégies de locators pour trouver les éléments d'upload/téléchargement
- [core/assertions-and-waiting.md](assertions-and-waiting.md) -- patterns d'assertion pour vérifier les résultats d'upload/téléchargement
- [core/fixtures-and-hooks.md](fixtures-and-hooks.md) -- création de fixtures réutilisables de répertoire de téléchargement
- [core/network-mocking.md](network-mocking.md) -- mock des endpoints d'upload pour des tests plus rapides
- [core/error-and-edge-cases.md](error-and-edge-cases.md) -- test des états d'échec et de la gestion d'erreurs d'upload
