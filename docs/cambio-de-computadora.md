# Cambio de computadora

Tu asistente de IA se puede mover a una computadora nueva en ~15 minutos. Tus datos no se pierden porque estan en Notion (en la nube).

## Que necesitas en la nueva computadora

1. Acceso a internet
2. Terminal (Mac: Terminal. Windows: WSL. Linux: cualquiera)

## Pasos

### 1. Instalar Node.js
```bash
# Mac (con Homebrew)
brew install node

# Linux / WSL
curl -fsSL https://fnm.vercel.app/install | bash
fnm install 22
```

### 2. Instalar Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

### 3. Loguearte con tu cuenta
```bash
claude
# Seguir las instrucciones para loguearte con tu cuenta de Claude Pro
```

### 4. Copiar tu configuracion
Necesitas copiar la carpeta `~/.claude/` desde tu computadora anterior. Si no la tenes, pedile a tu asistente que te ayude a recrearla.

Los archivos importantes son:
- `~/.claude/CLAUDE.md` — la identidad y reglas de tu asistente
- `~/.claude/express/` — scripts, configuracion, token de Notion
- `~/.claude/skills/` — tus agentes
- `~/.claude/settings.json` — hooks configurados

### 5. Verificar que funciona
```bash
claude
# Tu asistente deberia arrancar con el contexto de tu ultima sesion
```

## Que NO necesitas reinstalar

- **Notion:** tus datos estan en la nube, se conectan automaticamente
- **Tus agentes:** estan en los archivos que copiaste
- **Tu historial:** esta en Notion, no en tu computadora

## Si no tenes acceso a la computadora anterior

Contacta a Metodica (lucia@metodica.digital). Podemos:
- Regenerar tu configuracion desde el setup original
- Reconectar tu workspace de Notion
- Reinstalar tus agentes

Esto se puede hacer en una sesion de 30 minutos.
