# NÓ — suporte local (rede interna, com ou sem internet)

Build do app: commit `9cada26a5` (branch `master`).
Executável: `NO.exe`. Perfil em `%APPDATA%\NO` — não conflita com o RustDesk instalado.

## O que mudou neste build

- **Interface enxuta para suporte remoto**: a barra da sessão e os menus de
  conexão mostram apenas o fluxo essencial — tela, teclado/mouse, clipboard,
  arquivos, reinício, bloqueio de entrada e privacidade. Chat, voz, gravação,
  câmera, terminal, túnel TCP, impressora remota, 2FA e troca de ID ficaram
  fora desses menus; atalhos avançados continuam em Configurações.
- **Copiar dados de acesso**: no Modo suporte, o botão **Copiar dados de acesso**
  copia ID, senha e IP local de uma vez para enviar ao técnico.
- **Marca NÓ**: logo novo (N com nó e ondas), título da janela, ícone do app/bandeja
  e metadados do executável. Todo o nome ATHOS e o arqueiro foram removidos.
- **Atualizações offline (L3)**: pasta compartilhada com `no-version.json`; o app
  compara a versão e mostra o pacote disponível.
- **Instalador (L4)**: `Instalar-NO.exe` é um único EXE (Inno Setup) que copia o NÓ para `Program Files\NO`, cria atalhos, libera a porta 21118, instala o serviço, registra a desinstalação e abre o aplicativo.
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
- **Login do RustDesk removido**: as abas **Endereços** e **Dispositivos
  acessíveis** saíram da interface; a seção Account no mobile, a opção Note e o
  botão Note da sessão não existem mais; a nota/auditoria automática em nuvem
  fica desligada. Nenhum caminho visível abre OAuth ou a nuvem do RustDesk.
  A aba **Conta** local continua disponível no desktop.
- **Indicador de conexão**: a aba da sessão mostra **Direto** ou **Relay** e a
  latência em ms quando o par informa a medição. A conexão por IP direto não
  depende de servidor público.
- **Rede local**: a tela inicial mostra **Radmin VPN**, **Tailscale** e o
  **IP da máquina**, com status, IP e atalhos para copiar ou abrir o aplicativo
  oficial. O botão **Fixar IP** transforma o endereço atual em fixo no Windows;
  para evitar conflito, use um IP fora da faixa DHCP ou faça uma reserva por
  MAC no roteador. O NÓ só detecta a VPN já conectada; criar ou entrar na rede
  continua sendo feito no aplicativo.
- **Acesso por IP direto**: já vem ligado em uma instalação nova, para que a
  porta 21118 esteja escutando sem depender do servidor público. Pode ser
  desligado em **Configurações → Segurança → Habilitar Acesso IP Direto**.
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

1. Copie `Instalar-NO.exe` para a máquina.
2. Dê duplo clique e aceite o UAC.
   - O instalador é um único EXE e **não é assinado**. O Windows pode mostrar
     "editor desconhecido" ou o aviso do SmartScreen; use **Mais informações →
     Executar assim mesmo**.
   - Ele copia o NÓ para `C:\Program Files\NO`, cria os atalhos, libera a porta
     21118, instala o serviço, registra a desinstalação em **Aplicativos e
     recursos** e abre o NÓ ao final.
   - O instalador executa como administrador; o NÓ é aberto com o usuário normal.
   - Se algo falhar, o instalador mostra o erro. O log fica em
     `%TEMP%\NO-install.log`.
3. Abra o NÓ e confira no card **"Este dispositivo"**:
   - **Serviço: Em execução** (se aparecer **Ativar**, clique e aceite o UAC).
   - **Rede**: o instalador já criou as regras para Domínio, Particular e Público.
     Se aparecer **Pública**, é só o perfil da rede (comum em VPN); a porta 21118
     continua liberada. **Aplicar** recria as regras e não é obrigatório.
4. Defina uma **senha permanente** em **Configurações → Segurança**.
5. No painel **Rede local**, clique em **Fixar IP** para manter o endereço
   atual. Use um IP fora da faixa do DHCP do roteador; se preferir, faça uma
   **reserva DHCP por MAC** no roteador.

## Instalação opcional das VPNs

O assistente do `Instalar-NO.exe` mostra duas tarefas **desmarcadas**:

- **Tailscale** — recomendado para acesso externo; crie uma tailnet e mantenha
  a máquina controlada e o técnico na mesma rede.
- **Radmin VPN** — alternativa quando o Tailscale não estiver disponível.

As duas opções precisam de internet durante a instalação. O instalador baixa o
pacote somente do site oficial, confere o SHA-256 fixado e a assinatura digital
do fabricante antes de executar. Se o download ou a verificação falhar, o NÓ
continua instalado e o motivo fica em `%TEMP%\NO-vpn-install.log`; o painel
**Rede local** mostra a VPN como não instalada.

A instalação não cria conta nem entra em nenhuma rede. Depois de instalar,
abra o Tailscale e faça login, ou abra o Radmin VPN e entre/crie a rede. O NÓ
detecta o IP da VPN já conectada. Reinicie o Windows se o instalador da VPN
solicitar.

Para instalar sem o assistente:

```powershell
# Tailscale
.\Instalar-NO.exe /SILENT /TASKS="vpn_tailscale"

# Radmin VPN
.\Instalar-NO.exe /SILENT /TASKS="vpn_radmin"

# As duas
.\Instalar-NO.exe /SILENT /TASKS="vpn_tailscale,vpn_radmin"
```


> O ZIP portátil e os scripts `Instalar-NO.ps1`/`Instalar-NO.cmd` continuam
> disponíveis como alternativa, mas o caminho recomendado é o `Instalar-NO.exe`.

## Modo portátil (sem instalar)

1. Execute `NO.exe`.
2. No aviso do Windows, use **Mais informações → Executar assim mesmo**.
3. O modo portátil não instala o serviço do Windows. Para acesso sem abrir o
   app, use o **Instalar-NO.exe** (caminho recomendado).

## Desinstalação

1. Abra **Configurações → Aplicativos → Aplicativos e recursos** (Windows 10) ou
   **Aplicativos instalados** (Windows 11), localize **NÓ - suporte remoto local**
   e clique em **Desinstalar**. Aceite o UAC.
   - O `Instalar-NO.exe` registra o desinstalador do Inno Setup; a entrada funciona
     mesmo se o instalador original for apagado.
   - Também é possível executar `Desinstalar-NO.cmd` do pacote portátil, caso ele
     tenha sido usado.
2. O desinstalador remove o serviço, `C:\Program Files\NO`, as regras de firewall,
   os atalhos e a entrada de Aplicativos e recursos. O log da instalação fica em
   `%TEMP%\NO-install.log`.
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
- O `Instalar-NO.exe` é um EXE único, gerado pelo Inno Setup, e **não é assinado**.
  O Windows/SmartScreen pode mostrar "editor desconhecido"; isso não impede a
  instalação.
- O MSI gerado pelo build continua sendo o do upstream RustDesk e **não é
  distribuído**. O caminho recomendado é o `Instalar-NO.exe`; o ZIP portátil
  continua disponível como alternativa.
- Identificadores internos `rustdesk` (DLL, crate, AppID) permanecem; eles não
  aparecem na interface.
- Se no futuro houver um certificado de code signing, o mesmo instalador pode ser
  assinado antes da distribuição, sem mudar o fluxo de instalação.

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
- [ ] Card Serviço mostra **Em execução**/**Parado** e o botão **Ativar**/**Desativar**.
- [ ] Copiar dados de acesso usa o IP físico principal, não o IP de uma VPN.
- [ ] Acesso por IP direto já vem ligado em uma instalação nova (porta 21118).
- [ ] Instalador pergunta Tailscale/Radmin e instala a opção marcada.
- [ ] Painel Rede local detecta Radmin e Tailscale, mostra o IP e permite fixar o IP.
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
- [ ] Instalador EXE copia para Program Files, cria atalhos e abre o NÓ.
- [ ] Entrada **NÓ - suporte remoto local** aparece em Aplicativos e recursos.
- [ ] Desinstalar remove o app e preserva `%APPDATA%\NO`.
- [ ] Aba remota mostra **Direto** ou **Relay** e a latência quando disponível.
- [ ] Sessão por IP direto funciona sem internet.
- [ ] Mouse, teclado, H.264 e área de transferência.

## Se não conectar

- Confira se a máquina controlada está **ligada** e com o **serviço** instalado.
- O NÓ ativa o **acesso por IP direto** na primeira execução. Se estiver
  desligado, abra **Configurações → Segurança** e marque
  **Habilitar Acesso IP Direto**.
- **Rede: Pública** não bloqueia: as regras do instalador valem para os três perfis.
  Se o botão **Aplicar** aparecer, ele recria as regras (aceite o UAC).
- Confira a reserva de IP no roteador.
- Teste a porta no destino: `Test-NetConnection <IP> -Port 21118`.
  - Se o **ping** responde mas a porta falha, o NÓ do destino não está
    escutando: serviço parado/removido, aplicativo fechado ou acesso por IP
    desativado.
  - Se a porta responde, confira a senha e o ID/IP usado na conexão.
- A mensagem **Failed to connect to ...** seguida da dica de rede significa que
  a porta 21118 não aceitou a conexão. Corrija o destino antes de tentar de novo.

## Acesso remoto: sugestões de uso

- **Mesma rede**: use o **IP local** e o botão **Fixar IP**. Prefira um IP fora
  da faixa do DHCP ou uma reserva por MAC no roteador. Se a máquina mudar de
  rede, use **Usar automático** para voltar ao DHCP.
- **Fora da rede**: use **Tailscale** como primeira opção; mantenha a máquina
  controlada e o técnico na mesma tailnet. Use **Radmin VPN** como alternativa
  quando o Tailscale não estiver disponível na rede.
- **Nunca exponha a porta 21118 diretamente na internet.** O acesso externo deve
  passar por Tailscale ou Radmin VPN.
- **Atendimento rápido**: abra **Modo suporte → Copiar dados de acesso** e envie
  ID, senha e IP em uma única mensagem. Para acesso sem alguém na máquina,
  configure uma senha permanente com pelo menos 8 caracteres.
- **Durante a sessão**: use transferência de arquivos para enviar instaladores,
  bloqueio de entrada apenas quando necessário e privacidade quando a tela não
  puder ser vista por terceiros.
- **Depois do atendimento**: troque a senha se outra pessoa a conheceu, confira
  o serviço e o firewall e faça um teste de conexão de outro computador.
- **Manutenção**: guarde o `Instalar-NO.exe` e o SHA-256, teste a desinstalação
  em uma VM e lembre que `%APPDATA%\NO` é preservado.

## Segurança

- As senhas do catálogo e a senha da conta local são criptografadas com DPAPI
  do Windows, inclusive no arquivo de backup. O backup restaurado em outra
  máquina não revela as senhas; cadastre-as de novo lá.
- A conta local é um perfil salvo na máquina; para impedir o uso do NÓ por
  outra pessoa, proteja o acesso ao Windows e à pasta `%APPDATA%\NO`.
- Use uma senha permanente forte por máquina.
- O acesso por IP direto vem ligado por padrão para o suporte local. Se não
  precisar dele, desmarque **Habilitar Acesso IP Direto** em
  **Configurações → Segurança**.
- **Nunca exponha a porta 21118 na internet.** Para acesso externo, use
  Radmin VPN ou Tailscale.
- A instalação opcional das VPNs baixa apenas dos sites oficiais e verifica
  hash e assinatura; ela não entra em redes nem cria contas automaticamente.
- Acompanhe os patches de segurança do RustDesk upstream.
