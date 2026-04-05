# GitHub Actions - Автоматическая сборка IPA

## 🚀 Как использовать

### Вариант 1: Sideloading (бесплатно, через AltStore)

1. **Форкните этот репозиторий на GitHub**

2. **Добавьте Secrets в GitHub**:
   - Перейдите в Settings → Secrets and variables → Actions → New repository secret
   - Добавьте:
     - `TEAM_ID` - ваш Apple Team ID (найдите на https://developer.apple.com/account)
     - `CODE_SIGN_IDENTITY` - optional, `"iPhone Developer"`

3. **Запушите код** или запустите workflow вручную:
   ```bash
   git add .
   git commit -m "Build app"
   git push origin main
   ```

4. **Скачайте IPA**:
   - Дождитесь завершения workflow
   - Перейдите в Actions → Build IPA → Artifacts
   - Скачайте `ClaudeMobile_unsigned.ipa`

5. **Установите через AltStore**:
   - Установите AltStore на iPhone (https://altstore.io)
   - Подключите iPhone к Mac
   - Откройте AltStore → My Apps → + → Выберите IPA

### Вариант 2: TestFlight (платно, $99/год)

Если у вас Apple Developer Program:

1. В workflow раскомментируйте signed build
2. Добавьте секреты:
   - `APPLE_USERNAME` - email от Apple ID
   - `APPLE_PASSWORD` - пароль приложения (с 2FA)
   - `TEAM_ID` - ваш Team ID
3. Workflow автоматически загрузит в TestFlight

### Вариант 3: Локальная сборка

Если у вас есть Mac и Xcode:

```bash
cd /Users/olegha27/Documents/GitHub/Claude-code-for-iphone/iOS

# Соберите архив
xcodebuild -project ClaudeMobile.xcodeproj \
  -scheme ClaudeMobile \
  -archivePath build/ClaudeMobile.xcarchive \
  archive \
  -allowProvisioningUpdates

# Экспортируйте IPA
xcodebuild -exportArchive \
  -archivePath build/ClaudeMobile.xcarchive \
  -exportPath build \
  -exportOptionsPlist export.plist
```

## 📋 Secrets (GitHub Settings → Secrets)

| Secret | Описание | Где взять |
|--------|----------|-----------|
| `TEAM_ID` | Apple Team ID | https://developer.apple.com/account |
| `APPLE_USERNAME` | Apple ID email | Ваш email |
| `APPLE_PASSWORD` | App-specific password | https://appleid.apple.com/ (создайте пароль приложения) |

## ⚠️ Важные моменты

1. **Безплатный аккаунт Apple ID** (7 дней):
   - IPA будет подписан только на 7 дней
   - После нужно переустанавливать

2. **Paid Apple Developer** ($99/год):
   - Подпись на 1 год
   - Доступ к TestFlight

3. **Unsigned IPA** (0 дней):
   - Нужен jailbreak ИЛИ AltStore
   - AltStore автоматически подписывает при установке

## 🔄 Запуск сборки

### Автоматически (при пуше):
```bash
git commit -m "Update app [release]"  # Добавьте [release] для публикации
git push origin main
```

### Вручную:
1. Перейдите на GitHub в Actions
2. Выберите "Build IPA"
3. Нажмите "Run workflow"
```
