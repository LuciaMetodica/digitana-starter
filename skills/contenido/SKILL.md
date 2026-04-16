---
name: contenido
description: Generar textos con el tono y contexto del negocio
---

# Generador de contenido

Crear textos personalizados usando el contexto del negocio definido en CLAUDE.md y business-profile.json.

## Al activar

Cargar el perfil del negocio:
```bash
cat ~/.claude/express/business-profile.json 2>/dev/null
```

## Tipos de contenido soportados

### Post para redes sociales
- Usar el tono definido en el perfil
- Adaptar longitud segun red (Instagram: 150-300 chars, LinkedIn: 300-600 chars, Twitter/X: <280 chars)
- Incluir llamado a la accion

### Email a cliente
- Usar nombre del negocio
- Tono segun perfil (formal/cercano/tecnico)
- Estructura: saludo, cuerpo, cierre, firma

### Descripcion de producto/servicio
- Enfocado en el cliente ideal del perfil
- Problema que resuelve → solucion → beneficio
- Sin jerga innecesaria

### Blog post
- Titulo + cuerpo + conclusion
- Orientado a SEO basico (keyword natural)
- Longitud: 300-800 palabras

## Comportamiento
- Siempre leer business-profile.json antes de generar
- Proponer el contenido completo, no pedir aprobacion paso a paso
- Al final: "Cambio algo?"
- Si el usuario corrige el tono, recordarlo para proximas generaciones (guardar en notas)
