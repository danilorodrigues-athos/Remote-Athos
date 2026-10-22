# NÓ — suporte local (rede interna, com ou sem internet)

Build: commit `fbd33de65` (branch `master`).
Executável: `NO.exe`. Perfil em `%APPDATA%\NO` — não conflita com o RustDesk instalado.

## O que mudou neste build

- **Marca NÓ**: logo novo (N com nó e ondas), título da janela, ícone do app/bandeja
  e metadados do executável. Todo o nome ATHOS e o arqueiro foram removidos.
- **Atualizações offline (L3)**: pasta compartilhada com `no-version.json`; o app
  compara a versão e mostra o pacote disponível.
- **Instalador (L4)**: `Instalar-NO.ps1` copia para `Program Files\NO`, cria atalhos,
  libera a porta 21118, instala o serviço do Windows e registra a entrada de
  desinstalação em **Aplicativos e recursos**.
- **Renomeação (L4)**: serviço, pipe, pasta de configuração e regras de firewall
  agora usam `NO`.
- **Cards de atualização/instalação do upstream desativados no Windows**: a
  atualização oficial do RustDesk não aparece; use **Clientes → Atualizações** (L3).
- **Logo compacto**: o N estilizado forma a própria palavra NÓ, sem repetir a letra.
- **Janela de conexão NÓ**: card do cliente e permissões com o visual da marca,
  mantendo só o que é útil — teclado, clipboard, arquivos, reiniciar, bloquear
  entrada e privacidade. Na conexão remota, chat, áudio e gravação não aparecem.
- **Senha permanente**: o diálogo "Definir Senha" agora exige só o tamanho
  mínimo de 8 caracteres; não exige dígito, maiúscula, minúscula nem especial.
- **Login do RustDesk removido**: a seção Account no mobile, a opção Note e o
  botão Note da sessão não existem mais; a nota/auditoria automática em nuvem
  fica desligada. Nenhum caminho visível abre OAuth ou a nuvem do RustDesk.
  A aba **Conta** local continua disponível no desktop.
- **Indicador de conexão**: a aba da sessão mostra **Direto** ou **Relay** e a
  latência em ms quando o par informa a medição. A conexão por IP direto não
  depende de servidor público.
- **Painel VPN**: a tela inicial mostra **Radmin VPN** e **Tailscale**, com
  status, IP virtual e atalhos para copiar o IP ou abrir o aplicativo oficial.
  O NÓ só detecta a VPN já conectada; criar ou entrar na rede continua sendo
  feito no aplicativo de cada VPN.
- **Conta local**: a aba **Conta** agora cria uma conta só nesta máquina —
  o nome fica em `%APPDATA%\NO` e a senha local é protegida com DPAPI.
  Não abre Google, GitHub ou Microsoft e não usa o cadastro do RustDesk.
  A conta é um perfil local; ela não bloqueia a abertura do aplicativo.
- **Sobre NÓ**: removidos os links "Declaração de Privacidade" e "Website"
  (`rustdesk.com`); a página mantém versão, data de build, fingerprint, ID e
  copyright, com a frase da marca NÓ no bloco azul.
- **Escanear rede**: ignora os IPs da própria máquina e corrige o filtro de MAC.
- Mantidos: catálogo de clientes, online/offline, hostname com auto-correção de IP,
  histórico, senhas com DPAPI, modo suporte e diagnóstico de firewall.

## Instalação recomendada (máquina controlada)

1. Copie esta pasta para a máquina.
2. Execute `Instalar-NO.cmd` (duplo clique) e aceite o UAC.
   - Também funciona clicar com o botão direito em `Instalar-NO.ps1` →
     **Executar com PowerShell**; o script solicita a elevação sozinho.
   - O script copia para `C:\Program Files\NO`, cria atalhos, libera a porta 21118,
     instala o serviço e registra a entrada em **Aplicativos e recursos**.
   - Se o NÓ abrir sozinho ao final da instalação, feche essa janela e abra pelo
     atalho. O atalho inicia o app **sem** privilégios de administrador.
   - Se algo falhar, a janela mostra o erro e o log fica em
     `%TEMP%\NO-install.log`.

> **A janela fecha sem instalar?** Use `Instalar-NO.cmd` e aceite o UAC.
> Se a elevação for recusada, a cópia para `C:\Program Files` e as regras de
> firewall falham.
3. Abra o NÓ e confira no card **"Este dispositivo"**:
   - **Serviço: Ativo** (se aparecer **Instalar**, clique e aceite o UAC).
   - **Rede**: o instalador já criou as regras para Domínio, Particular e Público.
     Se aparecer **Pública**, é só o perfil da rede (comum em VPN); a porta 21118
     continua liberada. **Aplicar** recria as regras e não é obrigatório.
4. Defina uma **senha permanente** em **Configurações → Segurança**.
5. No roteador, faça uma **reserva DHCP por MAC** para o IP não mudar.

## Modo portátil (sem instalar)

1. Execute `NO.exe`.
2. No aviso do Windows, use **Mais informações → Executar assim mesmo**.
3. Para acesso sem abrir o app, clique em **Serviço → Instalar**.
   - O serviço aponta para a pasta atual; não mova a pasta depois de instalar.

## Desinstalação

1. Abra **Configurações → Aplicativos → Aplicativos e recursos** (Windows 10) ou
   **Aplicativos instalados** (Windows 11), localize **NÓ - suporte remoto local**
   e clique em **Desinstalar**. Aceite o UAC.
   - A entrada funciona mesmo se a pasta do ZIP for movida: o instalador copia os
     scripts de desinstalação para `C:\ProgramData\NO`.
   - Também é possível executar `Desinstalar-NO.cmd` do pacote e aceitar o UAC.
2. O script remove o serviço, `C:\Program Files\NO`, as regras de firewall, os
   atalhos, a entrada de Aplicativos e recursos e os scripts auxiliares em
   `C:\ProgramData\NO`. O log fica em `%TEMP%\NO-uninstall.log`.
3. `%APPDATA%\NO` (ID, senha, catálogo e pasta de atualizações) é **preservado**.
   Para apagar tudo, exclua essa pasta manualmente.

## Atualizações offline (L3)

1. Na máquina controladora, abra **Clientes → Atualizações**.
2. Escolha a pasta compartilhada (ex.: `\\servidor\atualizacoes` ou `C:\NO\updates`).
3. Coloque na pasta o manifesto `no-version.json` e o ZIP do pacote:

   ```json
   {
     "version": "1.5.2",
     "file": "NO-MVP-1.5.2.zip",
     "notes": "Correções e melhorias."
   }
   ```

   Use `modelo-no-version.json` como base.
4. Clique em **Verificar agora**. Se a versão for maior que a atual, o app mostra o
   pacote e as notas.
5. Para atualizar: feche o NÓ, substitua os arquivos (ou rode o instalador) e abra
   de novo. O catálogo e as senhas ficam em `%APPDATA%\NO` e são preservados.

## Renomeação e assinatura (L4)

- Executável entregue: `NO.exe`; serviço, pipe e configuração: `NO`.
- O MSI gerado pelo build continua sendo o do upstream RustDesk e **não é
  distribuído**. Use o ZIP portátil + `Instalar-NO.ps1`.
- **Assinatura de código**: este build não tem certificado. Para assinar, é preciso
  um certificado Authenticode e configurar os secrets de assinatura no workflow.
  Sem isso, o Windows/SmartScreen mostra "editor desconhecido".
- Identificadores internos `rustdesk` (DLL, crate, AppID) permanecem; eles não
  aparecem na interface.

## Migração do ATHOSDESK

Esta versão usa o perfil novo `%APPDATA%\NO`. O catálogo antigo não é importado
automaticamente. Se você já cadastrou clientes no ATHOSDESK:

1. Abra o pacote antigo e use **Clientes → Exportar**.
2. No NÓ, use **Clientes → Importar** e escolha o JSON exportado.
   As senhas continuam legíveis nesta mesma máquina (DPAPI).

## Checklist de teste

- [ ] Janela abre com título **NÓ** e logo NÓ.
- [ ] Ícone da janela/bandeja é o NÓ (não o arqueiro).
- [ ] Card "Este dispositivo" mostra IP, serviço e rede.
- [ ] Painel VPN detecta Radmin/Tailscale, mostra o IP virtual e abre o app.
- [ ] Serviço instala e a máquina fica acessível após reiniciar.
- [ ] Diagnóstico de rede aplica as regras do firewall.
- [ ] Modo suporte mostra ID/IP/senha em tamanho legível.
- [ ] Catálogo mostra online/offline e "vista por último".
- [ ] Hostname corrige o IP sozinho quando o DHCP muda.
- [ ] Escanear rede não lista a própria máquina.
- [ ] Histórico registra data/hora e duração.
- [ ] Atualizações: escolher pasta, verificar versão e abrir o pacote.
- [ ] Janela de conexão mostra o card NÓ, o status e só as permissões úteis.
- [ ] Definir Senha aceita qualquer combinação com pelo menos 8 caracteres.
- [ ] Conta local não mostra Google/GitHub/Microsoft; a conta permanece após
      fechar e abrir o NÓ.
- [ ] Sobre NÓ não tem links para `rustdesk.com` e mostra a frase da marca.
- [ ] Instalador copia para Program Files e cria atalhos.
- [ ] Entrada **NÓ - suporte remoto local** aparece em Aplicativos e recursos.
- [ ] Desinstalar remove o app e preserva `%APPDATA%\NO`.
- [ ] Aba remota mostra **Direto** ou **Relay** e a latência quando disponível.
- [ ] Sessão por IP direto funciona sem internet.
- [ ] Mouse, teclado, H.264 e área de transferência.

## Se não conectar

- Confira se a máquina controlada está **ligada** e com o **serviço** instalado.
- **Rede: Pública** não bloqueia: as regras do instalador valem para os três perfis.
  Se o botão **Aplicar** aparecer, ele recria as regras (aceite o UAC).
- Confira a reserva de IP no roteador.
- Teste a porta: `Test-NetConnection <IP> -Port 21118`.

## Segurança

- As senhas do catálogo e a senha da conta local são criptografadas com DPAPI
  do Windows, inclusive no arquivo de backup. O backup restaurado em outra
  máquina não revela as senhas; cadastre-as de novo lá.
- A conta local é um perfil salvo na máquina; para impedir o uso do NÓ por
  outra pessoa, proteja o acesso ao Windows e à pasta `%APPDATA%\NO`.
- Use uma senha permanente forte por máquina.
- **Nunca exponha a porta 21118 na internet.** Para acesso externo, use
  Radmin VPN, WireGuard ou Tailscale.
- Acompanhe os patches de segurança do RustDesk upstream.
