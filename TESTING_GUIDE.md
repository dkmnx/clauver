# Guía de Testing - Clauver v1.6.1

## Ejecución Rápida

```bash
cd /home/daniel/claudecode/clauver
./test_security_improvements.sh
```

**Resultado esperado**: 27/27 tests pasados ✓

---

## Tests Manuales Recomendados

### Test 1: Verificar la Nueva Versión

```bash
# Ver versión actual
cd /home/daniel/claudecode/clauver
grep VERSION= clauver.sh | head -1
# Debería mostrar: VERSION="1.6.1"
```

### Test 2: Validar Verificación SHA256

```bash
# Crear archivo de prueba
echo "test content" > /tmp/test_file.txt

# Generar checksum correcto
sha256sum /tmp/test_file.txt > /tmp/test_file.sha256

# Extraer solo el hash
CORRECT_HASH=$(cat /tmp/test_file.sha256 | awk '{print $1}')

# Probar función verify_sha256 (requiere source del script)
source /home/daniel/claudecode/clauver/clauver.sh
verify_sha256 /tmp/test_file.txt "$CORRECT_HASH"
# Debería mostrar: "✓ SHA256 verification passed"

# Probar con hash incorrecto
WRONG_HASH="0000000000000000000000000000000000000000000000000000000000000000"
verify_sha256 /tmp/test_file.txt "$WRONG_HASH"
# Debería mostrar: "✗ SHA256 mismatch! File may be corrupted or tampered."

# Limpiar
rm /tmp/test_file.txt /tmp/test_file.sha256
```

### Test 3: Validar Age Exit Code

```bash
# Verificar que age está instalado
command -v age || echo "age no está instalado"
command -v age-keygen || echo "age-keygen no está instalado"

# Si age está instalado, probar decryption
if command -v age &>/dev/null; then
  # Crear claves de prueba
  age-keygen -o /tmp/key1.txt 2>/dev/null
  age-keygen -o /tmp/key2.txt 2>/dev/null

  # Encriptar con key1
  echo "SECRET_VALUE=test123" | age -e -i /tmp/key1.txt > /tmp/test.age 2>/dev/null

  # Desencriptar con clave correcta (debería funcionar)
  age -d -i /tmp/key1.txt /tmp/test.age 2>&1 | grep "SECRET_VALUE=test123" && echo "✓ Decryption exitosa"

  # Intentar desencriptar con clave incorrecta (debería fallar)
  if age -d -i /tmp/key2.txt /tmp/test.age 2>&1; then
    echo "✗ Debería haber fallado con clave incorrecta"
  else
    echo "✓ Falló correctamente con clave incorrecta"
  fi

  # Limpiar
  rm /tmp/key1.txt /tmp/key2.txt /tmp/test.age
fi
```

### Test 4: Validar Python3 Check

```bash
# Verificar que python3 está instalado
if command -v python3 &>/dev/null; then
  echo "✓ Python3 está instalado: $(python3 --version)"
else
  echo "✗ Python3 NO está instalado (función get_latest_version fallará correctamente)"
fi

# Verificar que la función lo valida
grep -A 5 "^get_latest_version()" /home/daniel/claudecode/clauver/clauver.sh | grep -q "command -v python3" && echo "✓ Validación de python3 presente en código"
```

### Test 5: Validar Inicialización de Variables

```bash
# Verificar que las variables están inicializadas
grep "ZAI_API_KEY=\"\${ZAI_API_KEY:-}\"" /home/daniel/claudecode/clauver/clauver.sh && echo "✓ ZAI_API_KEY inicializada"
grep "MINIMAX_API_KEY=\"\${MINIMAX_API_KEY:-}\"" /home/daniel/claudecode/clauver/clauver.sh && echo "✓ MINIMAX_API_KEY inicializada"
grep "KIMI_API_KEY=\"\${KIMI_API_KEY:-}\"" /home/daniel/claudecode/clauver/clauver.sh && echo "✓ KIMI_API_KEY inicializada"
grep "KATCODER_API_KEY=\"\${KATCODER_API_KEY:-}\"" /home/daniel/claudecode/clauver/clauver.sh && echo "✓ KATCODER_API_KEY inicializada"
```

### Test 6: Validar Config Sanitization

```bash
# Verificar que la validación de claves existe
grep -A 10 "^set_config()" /home/daniel/claudecode/clauver/clauver.sh | grep -q "Invalid config key" && echo "✓ Validación de claves presente"

# El siguiente test requiere source del script y es más complejo
# Se recomienda usar el test suite automatizado en su lugar
```

### Test 7: Validar Sintaxis General

```bash
# Verificar sintaxis bash
bash -n /home/daniel/claudecode/clauver/clauver.sh && echo "✓ Sintaxis bash válida"

# Verificar presencia de set -euo pipefail
head -5 /home/daniel/claudecode/clauver/clauver.sh | grep -q "set -euo pipefail" && echo "✓ Strict mode habilitado"

# Verificar umask restrictivo
head -10 /home/daniel/claudecode/clauver/clauver.sh | grep -q "umask 077" && echo "✓ Umask restrictivo configurado"
```

### Test 8: Verificar Documentación

```bash
# Verificar que los archivos de documentación existen
ls -lh /home/daniel/claudecode/clauver/SECURITY_IMPROVEMENTS.md && echo "✓ SECURITY_IMPROVEMENTS.md presente"
ls -lh /home/daniel/claudecode/clauver/CHANGELOG_v1.6.1.md && echo "✓ CHANGELOG_v1.6.1.md presente"
ls -lh /home/daniel/claudecode/clauver/IMPLEMENTATION_SUMMARY.md && echo "✓ IMPLEMENTATION_SUMMARY.md presente"
ls -lh /home/daniel/claudecode/clauver/test_security_improvements.sh && echo "✓ test_security_improvements.sh presente"

# Verificar que test script es ejecutable
[ -x /home/daniel/claudecode/clauver/test_security_improvements.sh ] && echo "✓ Test script es ejecutable"
```

---

## Test de Integración Completo

```bash
#!/bin/bash
# Script para test de integración completo

echo "=== Test de Integración Clauver v1.6.1 ==="
echo

# 1. Verificar sintaxis
echo "1. Verificando sintaxis..."
bash -n /home/daniel/claudecode/clauver/clauver.sh && echo "   ✓ Sintaxis válida" || echo "   ✗ ERROR de sintaxis"

# 2. Verificar versión
echo "2. Verificando versión..."
CURRENT_VERSION=$(grep "^VERSION=" /home/daniel/claudecode/clauver/clauver.sh | head -1 | cut -d'"' -f2)
if [ "$CURRENT_VERSION" = "1.6.1" ]; then
  echo "   ✓ Versión correcta: $CURRENT_VERSION"
else
  echo "   ✗ Versión incorrecta: $CURRENT_VERSION (esperada: 1.6.1)"
fi

# 3. Verificar función verify_sha256
echo "3. Verificando función verify_sha256..."
grep -q "^verify_sha256()" /home/daniel/claudecode/clauver/clauver.sh && echo "   ✓ Función verify_sha256 presente" || echo "   ✗ Función verify_sha256 NO encontrada"

# 4. Verificar validación de age exit code
echo "4. Verificando validación de age exit code..."
grep -A 10 "^load_secrets()" /home/daniel/claudecode/clauver/clauver.sh | grep -q "decrypt_exit=\$?" && echo "   ✓ Exit code de age validado" || echo "   ✗ Validación de exit code NO encontrada"

# 5. Verificar validación de python3
echo "5. Verificando validación de python3..."
grep -A 5 "^get_latest_version()" /home/daniel/claudecode/clauver/clauver.sh | grep -q "command -v python3" && echo "   ✓ Validación de python3 presente" || echo "   ✗ Validación de python3 NO encontrada"

# 6. Verificar inicialización de variables
echo "6. Verificando inicialización de variables..."
VAR_COUNT=0
grep -q "ZAI_API_KEY=\"\${ZAI_API_KEY:-}\"" /home/daniel/claudecode/clauver/clauver.sh && VAR_COUNT=$((VAR_COUNT + 1))
grep -q "MINIMAX_API_KEY=\"\${MINIMAX_API_KEY:-}\"" /home/daniel/claudecode/clauver/clauver.sh && VAR_COUNT=$((VAR_COUNT + 1))
grep -q "KIMI_API_KEY=\"\${KIMI_API_KEY:-}\"" /home/daniel/claudecode/clauver/clauver.sh && VAR_COUNT=$((VAR_COUNT + 1))
grep -q "KATCODER_API_KEY=\"\${KATCODER_API_KEY:-}\"" /home/daniel/claudecode/clauver/clauver.sh && VAR_COUNT=$((VAR_COUNT + 1))
echo "   ✓ $VAR_COUNT/4 variables inicializadas"

# 7. Verificar sanitización de config
echo "7. Verificando sanitización de config..."
grep -A 10 "^set_config()" /home/daniel/claudecode/clauver/clauver.sh | grep -q "Invalid config key" && echo "   ✓ Sanitización de claves presente" || echo "   ✗ Sanitización NO encontrada"

# 8. Verificar documentación
echo "8. Verificando documentación..."
DOC_COUNT=0
[ -f "/home/daniel/claudecode/clauver/SECURITY_IMPROVEMENTS.md" ] && DOC_COUNT=$((DOC_COUNT + 1))
[ -f "/home/daniel/claudecode/clauver/CHANGELOG_v1.6.1.md" ] && DOC_COUNT=$((DOC_COUNT + 1))
[ -f "/home/daniel/claudecode/clauver/IMPLEMENTATION_SUMMARY.md" ] && DOC_COUNT=$((DOC_COUNT + 1))
[ -x "/home/daniel/claudecode/clauver/test_security_improvements.sh" ] && DOC_COUNT=$((DOC_COUNT + 1))
echo "   ✓ $DOC_COUNT/4 archivos de documentación presentes"

echo
echo "=== Test de Integración Completo ==="
```

---

## Ejecución del Test Suite Completo

### Opción 1: Test Suite Automatizado (Recomendado)

```bash
cd /home/daniel/claudecode/clauver
./test_security_improvements.sh
```

**Output esperado**:
```
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   CLAUVER SECURITY IMPROVEMENTS TEST SUITE v1.6.1                    ║
║                                                                       ║
║   Testing all security enhancements implemented in latest release    ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝

ℹ INFO: Starting test suite...
ℹ INFO: Test script location: .

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TEST: SHA256 Verification Function
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ PASS: Valid SHA256 checksum verification
✓ PASS: Invalid SHA256 checksum rejection
✓ PASS: Detection of modified file

... [más tests] ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TEST SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total tests:  27
Passed:       27
Failed:       0

✓ ALL TESTS PASSED
```

### Opción 2: Tests Manuales Selectivos

Ejecuta los tests individuales de arriba según necesites validar componentes específicos.

---

## Troubleshooting

### Si algún test falla:

1. **Verificar requisitos**:
   ```bash
   command -v bash || echo "bash no encontrado"
   command -v sha256sum || echo "sha256sum no encontrado"
   command -v age || echo "age no encontrado (opcional)"
   command -v python3 || echo "python3 no encontrado"
   ```

2. **Verificar permisos**:
   ```bash
   ls -l /home/daniel/claudecode/clauver/clauver.sh
   ls -l /home/daniel/claudecode/clauver/test_security_improvements.sh
   ```

3. **Verificar sintaxis**:
   ```bash
   bash -n /home/daniel/claudecode/clauver/clauver.sh
   bash -n /home/daniel/claudecode/clauver/test_security_improvements.sh
   ```

4. **Revisar logs**:
   ```bash
   # Ejecutar test suite con debug
   bash -x /home/daniel/claudecode/clauver/test_security_improvements.sh 2>&1 | less
   ```

### Si sha256sum no está disponible:

```bash
# Debian/Ubuntu
sudo apt install coreutils

# Fedora/RHEL
sudo dnf install coreutils

# Arch Linux
sudo pacman -S coreutils

# macOS (debería estar incluido)
which sha256sum || which shasum
```

### Si age no está disponible:

```bash
# Debian/Ubuntu
sudo apt install age

# Fedora/RHEL
sudo dnf install age

# Arch Linux
sudo pacman -S age

# macOS
brew install age
```

---

## Archivos de Testing

### Ubicación
```
/home/daniel/claudecode/clauver/
├── clauver.sh (script principal)
├── test_security_improvements.sh (test suite)
├── TESTING_GUIDE.md (este archivo)
├── SECURITY_IMPROVEMENTS.md (documentación detallada)
├── CHANGELOG_v1.6.1.md (registro de cambios)
└── IMPLEMENTATION_SUMMARY.md (resumen técnico)
```

### Permisos Correctos
```bash
# Verificar permisos
ls -l /home/daniel/claudecode/clauver/*.sh

# Debería mostrar:
# -rwxr-xr-x clauver.sh
# -rwxr-xr-x test_security_improvements.sh

# Si no son ejecutables:
chmod +x /home/daniel/claudecode/clauver/clauver.sh
chmod +x /home/daniel/claudecode/clauver/test_security_improvements.sh
```

---

## Próximos Pasos

Después de que todos los tests pasen:

1. ✅ Revisar `SECURITY_IMPROVEMENTS.md` para detalles técnicos
2. ✅ Leer `CHANGELOG_v1.6.1.md` para lista de cambios
3. ✅ Consultar `IMPLEMENTATION_SUMMARY.md` para resumen ejecutivo
4. ✅ Si todo está bien, el script está listo para usar

---

**Versión**: 1.6.1
**Última actualización**: 2025-11-11
**Estado**: ✅ TODOS LOS TESTS PASANDO
