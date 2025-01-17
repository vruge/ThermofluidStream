within ThermofluidStream.Boundaries.Internal;
partial model PartialVolume "Partial parent class for Volumes with one inlet and outlet"

   replaceable package Medium = myMedia.Interfaces.PartialMedium "Medium model" annotation (
      choicesAllMatching=true, Documentation(info="<html>
<p><span style=\"font-family: Courier New;\">Medium package used in the Volume. Make sure it is the same as the inlets and outlets the volume is connected to.</span></p>
</html>"));

  parameter Boolean useHeatport = false "If true heatport is added";
  parameter Boolean useInlet = true "If true inlet is added";
  parameter Boolean useOutlet = true "If true outlet is added";
  parameter SI.Area A = 1 "Contact area of volume with medium"
    annotation(Dialog(enable=useHeatport));
  parameter SI.CoefficientOfHeatTransfer U = 200 "Heat transfer coefficient to medium"
    annotation(Dialog(enable=useHeatport));
  parameter Boolean initialize_pressure = true "If true: initialize Pressure"
    annotation(Dialog(tab= "Initialization"));
  parameter SI.Pressure p_start = Medium.p_default "Initial Pressure"
    annotation(Dialog(tab= "Initialization", enable=initialize_pressure));
  parameter Boolean initialize_energy = true "Initialize specific inner energy with temperature or specific enthalpy condition"
    annotation(Dialog(tab= "Initialization"));
  parameter SI.Temperature T_start = Medium.T_default "Initial Temperature"
    annotation(Dialog(tab= "Initialization", enable=initialize_energy and (not use_hstart)));
  parameter Boolean use_hstart = false "True: spedific enthalpy contition instead of Temperature"
    annotation(Dialog(tab= "Initialization", enable=initialize_energy));
  parameter SI.SpecificEnthalpy h_start = Medium.T_default "Initial specific enthalpy"
    annotation(Dialog(tab= "Initialization", enable=initialize_energy and use_hstart));
  parameter Medium.MassFraction Xi_0[Medium.nXi] = Medium.X_default[1:Medium.nXi] "Initial mass fraction"
    annotation(Dialog(tab= "Initialization"));
  parameter Utilities.Units.Inertance L = dropOfCommons.L "Inertance at inlet and outlet"
    annotation (Dialog(tab="Advanced"));
  parameter Real k_volume_damping(unit="1", min=0) = dropOfCommons.k_volume_damping "Damping factor multiplicator"
    annotation(Dialog(tab="Advanced", group="Damping"));
  parameter SI.MassFlowRate m_flow_assert(max=0) = -dropOfCommons.m_flow_reg "Assertion threshold for negative massflows"
    annotation(Dialog(tab="Advanced"));

  Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_a heatPort(Q_flow=Q_flow, T=T_heatPort) if useHeatport
    annotation (Placement(transformation(extent={{-10,-90},{10,-70}})));
  Interfaces.Inlet inlet(redeclare package Medium=Medium, m_flow=m_flow_in, r=r_in, state=state_in) if useInlet
    annotation (Placement(transformation(extent={{-120,
            -20},{-80,20}}),
                        iconTransformation(extent={{-120,-20},{-80,20}})));
  Interfaces.Outlet outlet(redeclare package Medium=Medium, m_flow=m_flow_out, r=r_out, state=state_out) if useOutlet
    annotation (Placement(transformation(extent={{80,-20},
            {120,20}}), iconTransformation(extent={{80,-20},{120,20}})));

  Medium.BaseProperties medium(preferredMediumStates=false);

  SI.Volume V;

  //setting the state is beneficial to make sure the non-linear system in the media model is always of size 1 (2 for some media models)
  SI.Mass M(stateSelect=StateSelect.always) = V*medium.d;
  SI.Mass MXi[Medium.nXi](each stateSelect=StateSelect.always) = M*medium.Xi;
  SI.Energy U_med(stateSelect=StateSelect.always) = M*medium.u;

  SI.HeatFlowRate Q_flow;
  SI.Power W_v;

protected
  outer DropOfCommons dropOfCommons;

  SI.Temperature T_heatPort;
  SI.Pressure r;

  Real d(unit="1/(m.s)") = k_volume_damping*sqrt(abs(2*L/(V*max(density_derp_h, 1e-10)))) "Friction factor for coupled boundaries";
  SI.DerDensityByPressure density_derp_h "Partial derivative of density by pressure";
  SI.Pressure r_damping = d*der(M);

  SI.Pressure p_in = Medium.pressure(state_in);
  // fix potential instabilities by setting the outgoing enthalpy and mass fraction to the medium state
  SI.SpecificEnthalpy h_in = if noEvent(m_flow_in >= 0) then Medium.specificEnthalpy(state_in) else medium.h;
  Medium.MassFraction Xi_in[Medium.nXi] = if noEvent(m_flow_in >= 0) then Medium.massFraction(state_in) else medium.Xi;

  Medium.ThermodynamicState state_out;
  SI.Pressure p_out = Medium.pressure(state_out);
  // fix potential instabilities by setting the incoming enthalpy and mass fraction inlet ones,
  // effectiveley removing the mass-flow related parts of the differential equations for U and MXi
  SI.SpecificEnthalpy h_out = if noEvent(-m_flow_out >= 0) then Medium.specificEnthalpy(state_out) else medium.h;
  Medium.MassFraction Xi_out[Medium.nXi] = if noEvent(-m_flow_out >= 0) then Medium.massFraction(state_out) else medium.Xi;

  SI.Pressure r_in, r_out;
  SI.MassFlowRate m_flow_in, m_flow_out;
  Medium.ThermodynamicState state_in;

initial equation
  if initialize_pressure then
    medium.p=p_start;
  end if;

  if initialize_energy then
    if use_hstart then
      medium.h = h_start;
    else
      medium.T=T_start;
    end if;
  end if;

  medium.Xi = Xi_0;

equation
  assert(m_flow_in > m_flow_assert, "Negative massflow at Volume inlet", dropOfCommons.assertionLevel);
  assert(-m_flow_out > m_flow_assert, "Positive massflow at Volume outlet", dropOfCommons.assertionLevel);

  der(m_flow_in)*L = r_in - r - r_damping;
  der(m_flow_out)*L = r_out - r_damping;

  r + p_in = p_out;

  der(M) = m_flow_in + m_flow_out;
  der(U_med) = W_v + Q_flow + h_in*m_flow_in + h_out*m_flow_out;
  der(MXi) = Xi_in*m_flow_in + Xi_out*m_flow_out;

  Q_flow = U*A*(T_heatPort - medium.T);

  if not useHeatport then
    T_heatPort = medium.T;
  end if;
  if not useInlet then
    m_flow_in = 0;
    state_in = Medium.setState_phX(Medium.p_default, Medium.h_default, Medium.X_default[1:Medium.nXi]);
  end if;
  if not useOutlet then
    m_flow_out = 0;
  end if;

  annotation (Icon(coordinateSystem(preserveAspectRatio=false), graphics={
        Ellipse(
          extent={{-56,76},{64,16}},
          lineColor={28,108,200},
          lineThickness=0.5,
          fillColor={215,215,215},
          fillPattern=FillPattern.Solid,
          pattern=LinePattern.None),
        Rectangle(
          extent={{-56,46},{64,-56}},
          lineColor={28,108,200},
          lineThickness=0.5,
          fillColor={215,215,215},
          fillPattern=FillPattern.Solid,
          pattern=LinePattern.None),
        Ellipse(
          extent={{-56,-28},{64,-88}},
          lineColor={28,108,200},
          lineThickness=0.5,
          fillColor={215,215,215},
          fillPattern=FillPattern.Solid,
          pattern=LinePattern.None),
        Line(
          points={{-100,0},{100,0}},
          color={28,108,200},
          thickness=0.5),
        Ellipse(
          extent={{-60,-20},{60,-80}},
          lineColor={28,108,200},
          lineThickness=0.5,
          fillColor={170,213,255},
          fillPattern=FillPattern.Solid),
        Rectangle(
          extent={{-60,50},{60,-50}},
          lineColor={28,108,200},
          lineThickness=0.5,
          fillColor={170,213,255},
          fillPattern=FillPattern.Solid,
          pattern=LinePattern.None),
        Ellipse(
          extent={{-60,80},{60,20}},
          lineColor={28,108,200},
          lineThickness=0.5,
          fillColor={170,213,255},
          fillPattern=FillPattern.Solid),
        Line(
          points={{-60,50},{-60,-52}},
          color={28,108,200},
          thickness=0.5),
        Line(
          points={{60,50},{60,-52}},
          color={28,108,200},
          thickness=0.5)}), Diagram(coordinateSystem(preserveAspectRatio=false)),
    Documentation(info="<html>
<p>This is the partial parent class for all unidirectional volumes with only one inlet and outlet. It is partial and is missing one equation for its volume or the medium pressure and one the volume work performed.</p>
<p>Conceptually a Volume is a Sink and a Source. It therefore defines the Level of inertial pressure r in a closed loop and acts as a Loop breaker.</p>
<p>Volumes implement a damping term on the change of the stored mass to dampen out fast, otherwise undamped oscillations that appear when connecting volumes directly to other volumes or other boundaries (source, sink, boundary_fore, boundary_rear). With the damping term these oscillations will be still very fast, but dampeend out, so a stiff solver might be able to handle them well. Damping is enabled by default and can be disabled by setting Advanced.k_volume_damping=0. </p>
<p>For to stability reasons, mass-flows in the wrong direction (fluid entering the outlet or exiting the inlet) is considered to have the enthalpy and mass-fractions of the medium in the volume. This results in a stable steady-state solution, since this method effectiveley removes the parts of the energy and mass-fraction differential equations, that are associated with mass-flows. </p>
</html>"));
end PartialVolume;
