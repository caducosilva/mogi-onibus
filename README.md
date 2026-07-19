# 🚌 Ônibus Mogi

**App Android não oficial com os horários de ônibus de Mogi das Cruzes (SP).**

Consulte as **83 linhas** da cidade de forma rápida, **offline** e sem anúncios.
O app mostra o **próximo ônibus** com base no horário e no dia da semana, e os
horários são atualizados pela internet **sem precisar reinstalar**.

> Dados extraídos do portal da **Secretaria de Mobilidade e Trânsito** de Mogi das Cruzes.

<!-- Sugestão: adicionar aqui prints da tela inicial e dos horários de uma linha. -->

---

## ✨ O que o app faz

- **83 linhas** com horários de **Dia Útil**, **Sábado** e **Domingo/Feriado**,
  nos dois sentidos (Ida / Volta).
- **Busca** por número da linha, nome ou bairro.
- **Destaque do próximo ônibus** conforme o horário atual.
- **100% offline** depois da primeira abertura.
- **Apoie com Pix** (opcional): QR Code e chave gerados no próprio aparelho.

## 📥 Como baixar e instalar (passo a passo)

1. Abra a página de **[Releases](../../releases/latest)** no celular.
2. Baixe o arquivo **`.apk`**.
3. Toque no arquivo e, se pedir, permita **"instalar de fontes desconhecidas"**.
4. Pronto! É compatível com **Android 5.0 ou superior**.

## 🔄 Atualizações (o que faz esse app ser especial)

Existem **dois tipos de atualização, independentes**:

| O quê | Como chega até você | Precisa reinstalar? |
|------|---------------------|---------------------|
| **Horários** | O app baixa o `schedules.json` novo do GitHub e avisa | ❌ Não |
| **App** | Quando sai um APK novo nos *Releases*, o app avisa (1x/dia até atualizar) | ✅ Sim |

Ou seja: quando a prefeitura muda um horário, você recebe a atualização **na
próxima vez que abrir o app**, sem baixar nada manualmente.

## 🔒 Privacidade

Não coleta dados pessoais. A única conexão com a internet é para buscar horários
novos e verificar se há uma versão nova do app.

## ⚖️ Aviso

Projeto pessoal e **não oficial**, sem afiliação com a Prefeitura ou com as
empresas operadoras. Confira sempre a
[fonte oficial](https://mobilidadeservicos.mogidascruzes.sp.gov.br/site/transportes).

---

## 🛠️ Para desenvolvedores

App **Flutter** com uma arquitetura de **atualização OTA em duas camadas** (dados
e binário), servindo os horários direto do repositório.

**Stack:** Flutter · Dart · `http` · `shared_preferences` · GitHub Releases API.

**Como funciona a atualização de horários:** o app compara o campo `data_versao`
do `assets/schedules.json` local com o do repositório (via `raw.githubusercontent`).
Se o remoto for mais novo, oferece aplicar. O binário é verificado pela API de
*releases* do GitHub (aviso no máximo 1x/dia até atualizar).

**Atualizar os horários (rotina semanal, sem gerar APK):**
```bash
python tools/scrape.py                       # regenera app/assets/schedules.json
git add app/assets/schedules.json
git commit -m "horarios: atualização semanal" && git push
```

**Build do app (quando o código muda):**
```bash
cd app
flutter pub get
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

**Estrutura:**
```
mogi-onibus/
├── app/                       # projeto Flutter
│   ├── assets/schedules.json  # horários (fonte da verdade do app)
│   └── lib/                   # UI, repositório, update service, doação Pix
├── tools/scrape.py            # raspador do site da prefeitura
└── README.md
```

## 📄 Licença

MIT © 2026 Carlos Eduardo (@caducosilva)

## Autor

**CADUCOSILVA** — [Carlos Eduardo (@caducosilva)](https://github.com/caducosilva)  
Contato: abobicarlo@gmail.com

Doações via PIX (chave aleatória): `f74458dc-2a36-49bd-9250-1cef4365ebb8`
