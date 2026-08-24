// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Sovereign28 is ReentrancyGuard {
    // ---------- ESTADO ----------
    address public primus;
    mapping(uint8 => mapping(address => bool)) public mansion;
    mapping(bytes32 => bool) public folioUsado;
    mapping(bytes32 => bool) public folioSuspendido;
    bool public paused;

    address public pendingPrimus;
    uint256 public pendingPrimusTimestamp;
    uint256 public constant TIMELOCK = 48 hours;

    // ---------- EVENTOS ----------
    event MansionAsignada(uint8 indexed mansion, address indexed wallet);
    event MansionRevocada(uint8 indexed mansion, address indexed wallet);
    event FolioValidado(bytes32 indexed folio, address indexed wallet);
    event FolioRevocado(bytes32 indexed folio, address indexed wallet);
    event FolioSuspendido(bytes32 indexed folio, address indexed wallet);
    event FolioReactivado(bytes32 indexed folio, address indexed wallet);
    event Pausado(bool indexed estado);
    event PrimusTransferido(address indexed nuevoPrimus);
    event PrimusTransferenciaIniciada(address indexed pending, uint256 timestamp);

    // ---------- MODIFICADORES ----------
    modifier soloPrimus() {
        require(msg.sender == primus, "KRONOS: Solo Primus");
        _;
    }

    modifier mansionValida(uint8 _m) {
        require(_m >= 1 && _m <= 28, "KRONOS: Mansion fuera de rango");
        _;
    }

    modifier soloMansion(uint8 _m) {
        require(mansion[_m][msg.sender], "KRONOS: No tienes esta mansion");
        _;
    }

    modifier cuandoActivo() {
        require(!paused || msg.sender == primus, "KRONOS: Contrato pausado");
        _;
    }

    // ---------- CONSTRUCTOR ----------
    constructor(address _primus) {
        require(_primus != address(0), "KRONOS: Primus no puede ser 0x0");
        primus = _primus;
        paused = false;

        // Primus tiene la Mansión 15 por defecto (Revocación)
        mansion[15][_primus] = true;
        emit MansionAsignada(15, _primus);
    }

    // ---------- GESTIÓN DE MANSIONES (SOLO PRIMUS) ----------
    function asignarMansion(uint8 _m, address _wallet) external soloPrimus mansionValida(_m) {
        require(_wallet != address(0), "KRONOS: Wallet invalida");
        mansion[_m][_wallet] = true;
        emit MansionAsignada(_m, _wallet);
    }

    function revocarMansion(uint8 _m, address _wallet) external soloPrimus mansionValida(_m) {
        require(_wallet != address(0), "KRONOS: Wallet invalida");
        if (_m == 15 && _wallet == primus) {
            revert("KRONOS: No puedes revocar M15 de Primus");
        }
        mansion[_m][_wallet] = false;
        emit MansionRevocada(_m, _wallet);
    }

    // ---------- TIMELOCK PARA PRIMUS ----------
    function iniciarTransferenciaPrimus(address _nuevoPrimus) external soloPrimus {
        require(_nuevoPrimus != address(0), "KRONOS: Direccion invalida");
        pendingPrimus = _nuevoPrimus;
        pendingPrimusTimestamp = block.timestamp;
        emit PrimusTransferenciaIniciada(_nuevoPrimus, block.timestamp);
    }

    function aceptarPrimus() external {
        require(msg.sender == pendingPrimus, "KRONOS: No eres el pendiente");
        require(block.timestamp >= pendingPrimusTimestamp + TIMELOCK, "KRONOS: Timelock no cumplido");
        primus = pendingPrimus;
        pendingPrimus = address(0);
        pendingPrimusTimestamp = 0;
        emit PrimusTransferido(primus);
    }

    // ---------- FUNCIONES DE NEGOCIO ----------
    function validarFolio(bytes32 _folio) external mansionValida(1) soloMansion(1) cuandoActivo nonReentrant {
        require(!folioUsado[_folio], "KRONOS: Folio ya usado");
        require(!folioSuspendido[_folio], "KRONOS: Folio suspendido");
        folioUsado[_folio] = true;
        emit FolioValidado(_folio, msg.sender);
    }

    function revocarFolio(bytes32 _folio) external mansionValida(15) soloMansion(15) cuandoActivo {
        require(folioUsado[_folio], "KRONOS: Folio no existe o ya revocado");
        folioUsado[_folio] = false;
        if (folioSuspendido[_folio]) {
            folioSuspendido[_folio] = false;
        }
        emit FolioRevocado(_folio, msg.sender);
    }

    function suspenderFolio(bytes32 _folio) external mansionValida(14) soloMansion(14) cuandoActivo {
        require(folioUsado[_folio], "KRONOS: Folio no existe");
        require(!folioSuspendido[_folio], "KRONOS: Ya suspendido");
        folioSuspendido[_folio] = true;
        emit FolioSuspendido(_folio, msg.sender);
    }

    function reactivarFolio(bytes32 _folio) external mansionValida(13) soloMansion(13) cuandoActivo {
        require(folioUsado[_folio], "KRONOS: Folio no existe");
        require(folioSuspendido[_folio], "KRONOS: No esta suspendido");
        folioSuspendido[_folio] = false;
        emit FolioReactivado(_folio, msg.sender);
    }

    function pausar() external mansionValida(28) soloMansion(28) {
        paused = !paused;
        emit Pausado(paused);
    }

    function emergenciaPausar() external soloPrimus {
        paused = !paused;
        emit Pausado(paused);
    }

    // ---------- CONSULTAS ----------
    function tieneMansion(uint8 _m, address _wallet) external view returns (bool) {
        require(_m >= 1 && _m <= 28, "KRONOS: Mansion invalida");
        return mansion[_m][_wallet];
    }

    function folioEstado(bytes32 _folio) external view returns (bool usado, bool suspendido) {
        return (folioUsado[_folio], folioSuspendido[_folio]);
    }
}