# ============================================================
#  SLIM BRAVE OPTIMIZER PRO (WPF / XAML EDITION) - STANDALONE
# ============================================================

#region BOOTSTRAPPER NATIVO (AUTO-ADMIN, STA Y OCULTAR CONSOLA)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSTA = ($Host.Runspace.ApartmentState -eq 'STA')

# 1. Si no es Admin o no está en modo gráfico (STA), se relanza a sí mismo de forma invisible
if (-not $isAdmin -or -not $isSTA) {
    if ($PSCommandPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}

# 2. Forzar invisibilidad de la ventana base (Consola) usando la API de Windows
if (-not ('Console.Window' -as [type])) {
    Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
    '
}
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null
#endregion

#region ENSAMBLADOS Y API DE WINDOWS (DWM)
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DwmApi {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
"@
#endregion

#region DETECCION DE TEMA Y COLORES DINAMICOS
$isLightTheme = $false
try {
    $themeReg = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
    if ($themeReg.AppsUseLightTheme -eq 1) { $isLightTheme = $true }
} catch {}

if ($isLightTheme) {
    $BgWindow="#F3F3F3"; $BgCard="#FFFFFF"; $BgCardHover="#F8F8F8"; $BorderColor="#E5E5E5"
    $TextPrimary="#1A1A1A"; $TextSecondary="#5E5E5E"; $AccentColor="#FF5500"; $ScrollThumb="#999999"
    $ToggleOffBg="#E4E4E4"; $ToggleOffBorder="#8A8A8A"; $ToggleKnobOff="#5C5C5C"; $ToggleKnobOn="#FFFFFF"
    
    $BgTel="#FFECE5"; $FgTel="#FF5500"
    $BgPriv="#E5F3FF"; $FgPriv="#0078D7"
    $BgBrave="#F4E8FF"; $FgBrave="#7B32C5"
    $BgPerf="#E8FAED"; $FgPerf="#107C41"
} else {
    $BgWindow="#202020"; $BgCard="#2D2D2D"; $BgCardHover="#323232"; $BorderColor="#333333"
    $TextPrimary="#FFFFFF"; $TextSecondary="#A0A0A0"; $AccentColor="#FF5500"; $ScrollThumb="#666666"
    $ToggleOffBg="#333333"; $ToggleOffBorder="#8A8A8A"; $ToggleKnobOff="#CECECE"; $ToggleKnobOn="#FFFFFF"
    
    $BgTel="#4A1D05"; $FgTel="#FF7A33"
    $BgPriv="#002B59"; $FgPriv="#60CDFF"
    $BgBrave="#3B1B61"; $FgBrave="#C285FF"
    $BgPerf="#0B3D1E"; $FgPerf="#42E66B"
}
#endregion

#region BASE DE DATOS DE CARACTERISTICAS (35 OPCIONES)
$BraveReg = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
$global:LockToggle = $false

$MasterFeatures = @(
    # --- TELEMETRIA ---
    @{ ID="Metrics"; Cat="Telemetria"; Bg=$BgTel; Fg=$FgTel; Title="Disable Metrics Reporting"; Desc="Bloquea el envio de metricas de uso y crashes."; Key="MetricsReportingEnabled"; Val=0; Type="DWord" },
    @{ ID="SBER"; Cat="Telemetria"; Bg=$BgTel; Fg=$FgTel; Title="Disable Safe Browsing Reporting"; Desc="Evita enviar informacion adicional de URLs a los servidores."; Key="SafeBrowsingExtendedReportingEnabled"; Val=0; Type="DWord" },
    @{ ID="URLData"; Cat="Telemetria"; Bg=$BgTel; Fg=$FgTel; Title="Disable URL Data Collection"; Desc="Desactiva la recoleccion anonima de URLs visitadas."; Key="UrlKeyedAnonymizedDataCollectionEnabled"; Val=0; Type="DWord" },
    @{ ID="Surveys"; Cat="Telemetria"; Bg=$BgTel; Fg=$FgTel; Title="Disable Feedback Surveys"; Desc="Oculta las encuestas de satisfaccion del navegador."; Key="FeedbackSurveysEnabled"; Val=0; Type="DWord" },

    # --- PRIVACIDAD ---
    @{ ID="SafBro"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Disable Safe Browsing"; Desc="Desactiva la proteccion activa contra sitios maliciosos."; Key="SafeBrowsingProtectionLevel"; Val=0; Type="DWord" },
    @{ ID="AutAdd"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Disable Autofill (Addresses)"; Desc="Evita que Brave guarde y autocompleta direcciones."; Key="AutofillAddressEnabled"; Val=0; Type="DWord" },
    @{ ID="AutCre"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Disable Autofill (Credit Cards)"; Desc="Evita que Brave guarde tarjetas de credito."; Key="AutofillCreditCardEnabled"; Val=0; Type="DWord" },
    @{ ID="PasMan"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Disable Password Manager"; Desc="Desactiva el gestor de claves integrado."; Key="PasswordManagerEnabled"; Val=0; Type="DWord" },
    @{ ID="BroSig"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Disable Browser Sign-in"; Desc="Bloquea el inicio de sesion de cuentas en el navegador."; Key="BrowserSignin"; Val=0; Type="DWord" },
    @{ ID="WebRtc"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Disable WebRTC IP Leak"; Desc="Fuerza que WebRTC no exponga tu IP real al usar VPN."; Key="WebRtcIPHandling"; Val="disable_non_proxied_udp"; Type="String" },
    @{ ID="Quic"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Disable QUIC Protocol"; Desc="Desactiva QUIC (UDP) forzando TCP (Mejora bloqueos de red)."; Key="QuicAllowed"; Val=0; Type="DWord" },
    @{ ID="Cookies3p"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Block Third Party Cookies"; Desc="Bloquea todas las cookies de rastreo transversal."; Key="BlockThirdPartyCookies"; Val=1; Type="DWord" },
    @{ ID="DoNotTrack"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Enable Do Not Track"; Desc="Envía la solicitud de no rastreo a los sitios web."; Key="EnableDoNotTrack"; Val=1; Type="DWord" },
    @{ ID="ForGooSaf"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Force Google SafeSearch"; Desc="Fuerza el filtro estricto en motores de busqueda."; Key="ForceGoogleSafeSearch"; Val=1; Type="DWord" },
    @{ ID="IPFS"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Disable IPFS"; Desc="Desactiva el protocolo descentralizado IPFS nativo."; Key="IPFSEnabled"; Val=0; Type="DWord" },
    @{ ID="DisIncMod"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Disable Incognito Mode"; Desc="Elimina la opcion de crear ventanas de incognito."; Key="IncognitoModeAvailability"; Val=1; Type="DWord" },
    @{ ID="ForIncMod"; Cat="Privacidad"; Bg=$BgPriv; Fg=$FgPriv; Title="Force Incognito Mode"; Desc="Obliga a que TODO el navegador corra siempre en incognito."; Key="IncognitoModeAvailability"; Val=2; Type="DWord" },

    # --- BRAVE CORE ---
    @{ ID="Rewards"; Cat="Brave Core"; Bg=$BgBrave; Fg=$FgBrave; Title="Disable Brave Rewards"; Desc="Deshabilita completamente el sistema de BAT y anuncios."; Key="BraveRewardsDisabled"; Val=1; Type="DWord" },
    @{ ID="Wallet"; Cat="Brave Core"; Bg=$BgBrave; Fg=$FgBrave; Title="Disable Brave Wallet"; Desc="Oculta y desactiva la billetera de criptomonedas."; Key="BraveWalletDisabled"; Val=1; Type="DWord" },
    @{ ID="VPN"; Cat="Brave Core"; Bg=$BgBrave; Fg=$FgBrave; Title="Disable Brave VPN"; Desc="Remueve el boton promocional y servicio VPN."; Key="BraveVPNDisabled"; Val=1; Type="DWord" },
    @{ ID="AIChat"; Cat="Brave Core"; Bg=$BgBrave; Fg=$FgBrave; Title="Disable Brave AI Chat"; Desc="Desactiva el asistente de inteligencia artificial integrado."; Key="BraveAIChatEnabled"; Val=0; Type="DWord" },
    @{ ID="BraShi"; Cat="Brave Core"; Bg=$BgBrave; Fg=$FgBrave; Title="Disable Brave Shields"; Desc="Desactiva globalmente el bloqueador de anuncios nativo."; Key="BraveShieldsDisabledForUrls"; Val='["https://*", "http://*"]'; Type="String" },
    @{ ID="Tor"; Cat="Brave Core"; Bg=$BgBrave; Fg=$FgBrave; Title="Disable Tor"; Desc="Bloquea la opcion de abrir ventanas privadas con red Tor."; Key="TorDisabled"; Val=1; Type="DWord" },
    @{ ID="DisSyn"; Cat="Brave Core"; Bg=$BgBrave; Fg=$FgBrave; Title="Disable Sync"; Desc="Deshabilita el sistema de sincronizacion entre dispositivos."; Key="SyncDisabled"; Val=1; Type="DWord" },

    # --- RENDIMIENTO Y BLOAT ---
    @{ ID="BgMode"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Background Mode"; Desc="Fuerza el cierre total del navegador al salir (libera RAM)."; Key="BackgroundModeEnabled"; Val=0; Type="DWord" },
    @{ ID="MediaRec"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Media Recommendations"; Desc="Desactiva recomendaciones en controles multimedia."; Key="MediaRecommendationsEnabled"; Val=0; Type="DWord" },
    @{ ID="Shopping"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Shopping List"; Desc="Desactiva funciones de compras y promociones comerciales."; Key="ShoppingListEnabled"; Val=0; Type="DWord" },
    @{ ID="AlwOpePDF"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Always Open PDF Externally"; Desc="Fuerza la descarga de PDFs en lugar de abrirlos en la ventana."; Key="AlwaysOpenPdfExternally"; Val=1; Type="DWord" },
    @{ ID="DisTra"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Translate"; Desc="Desactiva el banner emergente de traduccion de paginas."; Key="TranslateEnabled"; Val=0; Type="DWord" },
    @{ ID="DisSpe"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Spellcheck"; Desc="Desactiva la correccion ortografica (reduce uso de CPU)."; Key="SpellcheckEnabled"; Val=0; Type="DWord" },
    @{ ID="Promos"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Promotions"; Desc="Bloquea banners publicitarios nativos del navegador."; Key="PromotionsEnabled"; Val=0; Type="DWord" },
    @{ ID="SearchSugg"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Search Suggestions"; Desc="Desactiva autocompletado en barra de direcciones (mas rapido)."; Key="SearchSuggestEnabled"; Val=0; Type="DWord" },
    @{ ID="DisPri"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Printing"; Desc="Deshabilita por completo la funcion nativa de impresion."; Key="PrintingEnabled"; Val=0; Type="DWord" },
    @{ ID="DefBrowser"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Default Browser Prompt"; Desc="Oculta el molesto banner de establecer como predeterminado."; Key="DefaultBrowserSettingEnabled"; Val=0; Type="DWord" },
    @{ ID="DevToo"; Cat="Rendimiento"; Bg=$BgPerf; Fg=$FgPerf; Title="Disable Developer Tools"; Desc="Deshabilita las herramientas de desarrollo (F12 / Inspector)."; Key="DeveloperToolsDisabled"; Val=1; Type="DWord" }
)

# Llaves del perfil Optimizado
$ProfOptimizedKeys = @("MetricsReportingEnabled", "SafeBrowsingExtendedReportingEnabled", "UrlKeyedAnonymizedDataCollectionEnabled", "FeedbackSurveysEnabled", "WebRtcIPHandling", "QuicAllowed", "BlockThirdPartyCookies", "EnableDoNotTrack", "IPFSEnabled", "BraveRewardsDisabled", "BraveWalletDisabled", "BraveVPNDisabled", "BraveAIChatEnabled", "TorDisabled", "BackgroundModeEnabled", "MediaRecommendationsEnabled", "ShoppingListEnabled", "PromotionsEnabled", "SearchSuggestEnabled", "DefaultBrowserSettingEnabled")
$ProfPrivacyKeys = $ProfOptimizedKeys + @("SafeBrowsingProtectionLevel", "AutofillAddressEnabled", "AutofillCreditCardEnabled", "PasswordManagerEnabled", "BrowserSignin", "SyncDisabled", "ForceGoogleSafeSearch")
$ProfPerfKeys = $ProfOptimizedKeys + @("AlwaysOpenPdfExternally", "TranslateEnabled", "SpellcheckEnabled", "PrintingEnabled", "DeveloperToolsDisabled")
#endregion

#region CONSTRUCCION DEL XAML DINAMICO
$DynamicCardsXAML = ""
foreach ($f in $MasterFeatures) {
    $DynamicCardsXAML += @"
    <Border Style="{StaticResource CardStyle}">
        <Grid>
            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="150"/><ColumnDefinition Width="50"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="0,0,15,0">
                <Border Background="$($f.Bg)" BorderBrush="$($f.Fg)" BorderThickness="1" CornerRadius="4" Padding="6,2" HorizontalAlignment="Left" Margin="0,0,0,4">
                    <TextBlock Text="$($f.Cat)" Foreground="$($f.Fg)" FontSize="11" FontWeight="SemiBold"/>
                </Border>
                <TextBlock Text="$($f.Title)" Foreground="$TextPrimary" FontWeight="Medium" FontSize="14"/>
                <TextBlock Text="$($f.Desc)" Foreground="$TextSecondary" FontSize="12" Margin="0,2,0,0" TextWrapping="Wrap"/>
            </StackPanel>
            <TextBlock x:Name="Txt_$($f.ID)" Grid.Column="1" Text="Por Defecto" Foreground="$TextSecondary" FontSize="13" VerticalAlignment="Center" HorizontalAlignment="Right" Margin="0,0,10,0"/>
            <CheckBox x:Name="Tgl_$($f.ID)" Grid.Column="2" Style="{StaticResource WinToggle}" VerticalAlignment="Center" HorizontalAlignment="Right"/>
        </Grid>
    </Border>
"@
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Slim Brave Optimizer" Height="900" Width="1050" MinHeight="800" MinWidth="950"
        WindowStartupLocation="CenterScreen" Background="$BgWindow" 
        FontFamily="Segoe UI Variable, Segoe UI" ResizeMode="CanResize">
    
    <Window.Resources>
        <Style TargetType="ScrollBar"><Setter Property="Background" Value="Transparent" /><Setter Property="Width" Value="8" /><Setter Property="Margin" Value="4,0,0,0" /><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar"><Grid Background="Transparent"><Track x:Name="PART_Track" IsDirectionReversed="true"><Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="$ScrollThumb" CornerRadius="3" Opacity="0.8"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb></Track></Grid></ControlTemplate></Setter.Value></Setter></Style>
        <Style TargetType="Border" x:Key="CardStyle"><Setter Property="Background" Value="$BgCard"/><Setter Property="BorderBrush" Value="$BorderColor"/><Setter Property="BorderThickness" Value="1"/><Setter Property="CornerRadius" Value="4"/><Setter Property="Margin" Value="0,0,0,6"/><Setter Property="Padding" Value="16,12"/></Style>
        <Style TargetType="Button" x:Key="WinButton"><Setter Property="Background" Value="$BgCard"/><Setter Property="Foreground" Value="$TextPrimary"/><Setter Property="BorderBrush" Value="$BorderColor"/><Setter Property="BorderThickness" Value="1"/><Setter Property="Padding" Value="16,6"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="$BgCardHover"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
        <Style TargetType="CheckBox" x:Key="WinToggle"><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="CheckBox"><Grid Background="Transparent"><Border x:Name="Border" Width="40" Height="20" CornerRadius="10" Background="$ToggleOffBg" BorderBrush="$ToggleOffBorder" BorderThickness="1.5"><Ellipse x:Name="Knob" Width="12" Height="12" Fill="$ToggleKnobOff" HorizontalAlignment="Left" Margin="3,0,0,0"/></Border></Grid><ControlTemplate.Triggers><Trigger Property="IsChecked" Value="True"><Setter TargetName="Border" Property="Background" Value="$AccentColor"/><Setter TargetName="Border" Property="BorderBrush" Value="$AccentColor"/><Setter TargetName="Knob" Property="Fill" Value="$ToggleKnobOn"/><Setter TargetName="Knob" Property="HorizontalAlignment" Value="Right"/><Setter TargetName="Knob" Property="Margin" Value="0,0,4,0"/><Setter TargetName="Knob" Property="Width" Value="14"/><Setter TargetName="Knob" Property="Height" Value="14"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
    </Window.Resources>

    <Grid Margin="36,20,36,0">
        <Grid.RowDefinitions><RowDefinition Height="60"/><RowDefinition Height="*"/><RowDefinition Height="130"/></Grid.RowDefinitions>
        <StackPanel Grid.Row="0" Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock Text="Navegador > " Foreground="$TextSecondary" FontSize="24" FontWeight="SemiBold"/>
            <TextBlock Text="Slim Brave Optimizer Pro" Foreground="$TextPrimary" FontSize="24" FontWeight="SemiBold"/>
        </StackPanel>

        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Margin="0,10,0,10">
            <StackPanel Margin="0,0,10,0">
                
                <TextBlock Text="Perfiles de Optimización" Foreground="$TextPrimary" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                <Border Style="{StaticResource CardStyle}" Margin="0,0,0,25">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <Button x:Name="BtnProfDefault" Grid.Column="0" Style="{StaticResource WinButton}" Margin="0,0,10,0">
                            <StackPanel>
                                <TextBlock Text="Por Defecto" FontWeight="Bold" Foreground="$TextPrimary" HorizontalAlignment="Center"/>
                                <TextBlock Text="Restaurar valores" Foreground="$TextSecondary" FontSize="11" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnProfStandard" Grid.Column="1" Style="{StaticResource WinButton}" Margin="0,0,10,0">
                            <StackPanel>
                                <TextBlock Text="Estandar" FontWeight="Bold" Foreground="$TextPrimary" HorizontalAlignment="Center"/>
                                <TextBlock Text="Reglas basicas" Foreground="$TextSecondary" FontSize="11" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnProfOptimized" Grid.Column="2" Style="{StaticResource WinButton}" Margin="0,0,10,0" BorderBrush="$AccentColor" BorderThickness="2">
                            <StackPanel>
                                <TextBlock Text="Optimizado" FontWeight="Bold" Foreground="$TextPrimary" HorizontalAlignment="Center"/>
                                <TextBlock Text="Balance Ideal" Foreground="$TextSecondary" FontSize="11" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnProfPrivacy" Grid.Column="3" Style="{StaticResource WinButton}" Margin="0,0,10,0">
                            <StackPanel>
                                <TextBlock Text="Privacidad" FontWeight="Bold" Foreground="$TextPrimary" HorizontalAlignment="Center"/>
                                <TextBlock Text="Maximo bloqueo" Foreground="$TextSecondary" FontSize="11" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                        <Button x:Name="BtnProfPerf" Grid.Column="4" Style="{StaticResource WinButton}">
                            <StackPanel>
                                <TextBlock Text="Rendimiento" FontWeight="Bold" Foreground="$TextPrimary" HorizontalAlignment="Center"/>
                                <TextBlock Text="Velocidad pura" Foreground="$TextSecondary" FontSize="11" HorizontalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                </Border>

                <TextBlock Text="Estado Actual del Sistema" Foreground="$TextPrimary" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                <Border Style="{StaticResource CardStyle}" Margin="0,0,0,25">
                    <Grid>
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="160"/></Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                            <TextBlock Text="Cache de Navegacion de Brave" Foreground="$TextPrimary" FontWeight="Medium" FontSize="14"/>
                            <TextBlock x:Name="TxtCachePath" Text="Buscando directorio..." Foreground="$TextSecondary" FontSize="12" Margin="0,2,0,0"/>
                        </StackPanel>
                        <TextBlock x:Name="TxtCacheSize" Grid.Column="1" Text="Calculando..." Foreground="$AccentColor" FontSize="13" FontWeight="Bold" VerticalAlignment="Center" Margin="0,0,15,0"/>
                        <Button x:Name="BtnCleanCache" Grid.Column="2" Content="Limpiar Cache" Style="{StaticResource WinButton}"/>
                    </Grid>
                </Border>

                <TextBlock Text="Configuraciones Especificas" Foreground="$TextPrimary" FontSize="14" FontWeight="SemiBold" Margin="0,0,0,10"/>
                
                $DynamicCardsXAML

            </StackPanel>
        </ScrollViewer>

        <Border Grid.Row="2" Background="Transparent" BorderBrush="$BorderColor" BorderThickness="0,1,0,0">
            <TextBox x:Name="ConsoleOutput" Background="Transparent" Foreground="$TextSecondary" BorderThickness="0" FontFamily="Consolas" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Margin="0,10,0,10" FontSize="12"/>
        </Border>
    </Grid>
</Window>
"@
#endregion

#region INICIALIZACION SEGURA
try {
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $Window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Host "ERROR CRÍTICO AL DIBUJAR LA INTERFAZ XAML" -ForegroundColor Red
    exit
}

$ConsoleOutput = $Window.FindName("ConsoleOutput")
$BtnProfDefault = $Window.FindName("BtnProfDefault")
$BtnProfStandard = $Window.FindName("BtnProfStandard")
$BtnProfOptimized = $Window.FindName("BtnProfOptimized")
$BtnProfPrivacy = $Window.FindName("BtnProfPrivacy")
$BtnProfPerf = $Window.FindName("BtnProfPerf")

$TxtCachePath = $Window.FindName("TxtCachePath")
$TxtCacheSize = $Window.FindName("TxtCacheSize")
$BtnCleanCache = $Window.FindName("BtnCleanCache")
#endregion

#region LOGICA CORE
function Do-WpfEvents {
    $frame = New-Object System.Windows.Threading.DispatcherFrame
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{ $frame.Continue = $false }) | Out-Null
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

function Write-Log {
    param([string]$Msg, [string]$Lvl = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $ConsoleOutput.AppendText("$timestamp [$Lvl] $Msg`n")
    $ConsoleOutput.ScrollToEnd()
    Do-WpfEvents
}

function Apply-ToggleUIState {
    param($TextControl, $IsApplied)
    if ($IsApplied) { 
        $TextControl.Text = "Aplicado / Bloqueado"; 
        $TextControl.Foreground = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($AccentColor))) 
    } else { 
        $TextControl.Text = "Por Defecto"; 
        $TextControl.Foreground = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($TextSecondary))) 
    }
}

function Update-UIStates {
    if (-not (Test-Path $BraveReg)) { return }
    $global:LockToggle = $true 
    
    foreach ($f in $MasterFeatures) {
        $val = (Get-ItemProperty -Path $BraveReg -Name $f.Key -ErrorAction SilentlyContinue).($f.Key)
        $st = ($null -ne $val -and $val -eq $f.Val)
        $f.TglControl.IsChecked = $st
        Apply-ToggleUIState $f.TxtControl $st
    }

    $global:LockToggle = $false; Do-WpfEvents
}

function Check-CacheSize {
    $path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache\Cache_Data"
    if (Test-Path $path) {
        $TxtCachePath.Text = $path
        $sizeBytes = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
        $TxtCacheSize.Text = "$sizeMB MB"
    } else {
        $TxtCachePath.Text = "Directorio no encontrado"
        $TxtCacheSize.Text = "0 MB"
    }
}

function Update-ProfileButtonVisuals {
    param($ActiveBtn)
    $AllProfileButtons = @($BtnProfDefault, $BtnProfStandard, $BtnProfOptimized, $BtnProfPrivacy, $BtnProfPerf)
    
    foreach ($btn in $AllProfileButtons) {
        $btn.BorderThickness = 1
        $btn.BorderBrush = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($BorderColor)))
    }
    
    $ActiveBtn.BorderThickness = 2
    $ActiveBtn.BorderBrush = (New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.ColorConverter]::ConvertFromString($AccentColor)))
}

function Apply-ProfileList {
    param([array]$KeyList, [string]$ProfileName)
    Write-Log "Aplicando Perfil: $ProfileName..." "SYS"
    
    if (Test-Path $BraveReg) { Remove-Item -Path $BraveReg -Recurse -Force | Out-Null }
    New-Item -Path $BraveReg -Force | Out-Null

    if ($KeyList.Count -eq 0) { 
        Write-Log "Políticas limpiadas. Brave usará su estado de fábrica." "OK"
        Update-UIStates
        return 
    }

    foreach ($f in $MasterFeatures) {
        if ($KeyList -contains $f.Key) {
            Set-ItemProperty -Path $BraveReg -Name $f.Key -Value $f.Val -Type $f.Type -Force
        }
    }
    Write-Log "Perfil cargado exitosamente." "OK"
    Update-UIStates
}
#endregion

#region CONEXION DE EVENTOS (AISLADA Y SEGURA)
function Register-FeatureEvents {
    param ($Feat)
    
    $checkBlock = {
        if (-not $global:LockToggle) { 
            Set-ItemProperty -Path $BraveReg -Name $Feat.Key -Value $Feat.Val -Type $Feat.Type -Force
            Write-Log "$($Feat.Title) Activado." "POL"
            Update-UIStates 
        } 
    }.GetNewClosure()

    $uncheckBlock = {
        if (-not $global:LockToggle) { 
            Remove-ItemProperty -Path $BraveReg -Name $Feat.Key -ErrorAction SilentlyContinue
            Write-Log "$($Feat.Title) Restaurado." "POL"
            Update-UIStates 
        } 
    }.GetNewClosure()

    $Feat.TglControl.Add_Checked($checkBlock)
    $Feat.TglControl.Add_Unchecked($uncheckBlock)
}

foreach ($feature in $MasterFeatures) {
    $feature.TglControl = $Window.FindName("Tgl_$($feature.ID)")
    $feature.TxtControl = $Window.FindName("Txt_$($feature.ID)")
    Register-FeatureEvents -Feat $feature
}

$BtnCleanCache.Add_Click({
    $path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache\Cache_Data"
    if (Test-Path $path) {
        Write-Log "Limpiando Caché de Navegacion..." "INFO"
        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
        Check-CacheSize
        Write-Log "Cache limpiada con éxito." "OK"
    } else {
        Write-Log "No se encontro el directorio de cache." "WARN"
    }
})

$BtnProfDefault.Add_Click({ Update-ProfileButtonVisuals $BtnProfDefault; Apply-ProfileList @() "Por Defecto" })
$BtnProfStandard.Add_Click({ Update-ProfileButtonVisuals $BtnProfStandard; Apply-ProfileList $MasterFeatures.Key "Estándar (Base JSON)" })
$BtnProfOptimized.Add_Click({ Update-ProfileButtonVisuals $BtnProfOptimized; Apply-ProfileList $ProfOptimizedKeys "Optimizado (Tu Imagen)" })
$BtnProfPrivacy.Add_Click({ Update-ProfileButtonVisuals $BtnProfPrivacy; Apply-ProfileList $ProfPrivacyKeys "Privacidad Máxima" })
$BtnProfPerf.Add_Click({ Update-ProfileButtonVisuals $BtnProfPerf; Apply-ProfileList $ProfPerfKeys "Rendimiento Puro" })

$Window.Add_Loaded({ 
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
    $attrValue = if ($isLightTheme) { 0 } else { 1 }
    [DwmApi]::DwmSetWindowAttribute($hwnd, 20, [ref]$attrValue, 4) | Out-Null
    
    if (-not (Test-Path $BraveReg)) { New-Item -Path $BraveReg -Force | Out-Null }
    
    Update-ProfileButtonVisuals $BtnProfOptimized
    
    Write-Log "SlimBrave Optimizer Pro Inicializado y Blindado." "SYS"
    Check-CacheSize
    Update-UIStates 
})

$Window.ShowDialog() | Out-Null
#endregion