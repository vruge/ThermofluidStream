﻿within ThermofluidStream.Undirected.Boundaries.Internal;
partial model PartialVolume "Partial parent class for Volumes with one fore and one rear"
  replaceable package Medium = myMedia.Interfaces.PartialMedium "Medium model" annotation (
      choicesAllMatching=true, Documentation(info="<html>
<p><span style=\"font-family: Courier New;\">Medium package used in the Volume. Make sure it is the same as the fores and rears the volume is connected to.</span></p>
</html>"));

  parameter Boolean useHeatport = false "If true heatport is added";
  parameter Boolean useRear = true "If true rear is added";
  parameter Boolean useFore = true "If true fore is added";
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
  parameter SI.MassFlowRate m_flow_reg = dropOfCommons.m_flow_reg "Regularization threshold of mass flow rate"
    annotation(Dialog(tab="Advanced"));
  parameter Real k_volume_damping(unit="1") = dropOfCommons.k_volume_damping "Damping factor multiplicator"
    annotation(Dialog(tab="Advanced", group="Damping"));

  Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_a heatPort(Q_flow=Q_flow, T=T_heatPort) if useHeatport
    annotation (Placement(transformation(extent={{-10,-90},{10,-70}})));
  Interfaces.Rear rear(redeclare package Medium=Medium, m_flow=m_flow_rear, r=r_rear_port, state_rearwards=state_out, state_forwards=state_in_rear) if useRear
    annotation (Placement(transformation(extent={{-120,-20},{-80,20}}),
        iconTransformation(extent={{-120,-20},{-80,20}})));
  Interfaces.Fore fore(redeclare package Medium=Medium, m_flow=m_flow_fore, r=r_fore_port, state_forwards=state_out, state_rearwards=state_in_fore) if useFore
    annotation (Placement(transformation(extent={{80,-20},{120,20}}),
        iconTransformation(extent={{80,-20},{120,20}})));

  Medium.BaseProperties medium(preferredMediumStates=false);

  SI.Volume V;

  //setting the state is beneficial to make sure the non-linear system in the media model is always of size 1 (2 for some media models)´
  SI.Mass M(stateSelect=StateSelect.always) = V*medium.d;
  SI.Mass MXi[Medium.nXi](each stateSelect=StateSelect.always) = M*medium.Xi;
  SI.Energy U_med(stateSelect=StateSelect.always) = M*medium.u;

  SI.HeatFlowRate Q_flow;
  SI.Power W_v;

protected
  outer DropOfCommons dropOfCommons;

  SI.Temperature T_heatPort;

  //if port.m_flow > 0 -> it is sink (r=medium.p-p_in) else it is source (r=0)
  SI.Pressure r_rear_intern = ThermofluidStream.Undirected.Internal.regStep(   m_flow_rear, p_out - Medium.pressure(state_in_rear), 0, m_flow_reg);
  SI.Pressure r_fore_intern = ThermofluidStream.Undirected.Internal.regStep(   m_flow_fore, p_out - Medium.pressure(state_in_fore), 0, m_flow_reg);
  // dont regstep variables that are only in der(state), to increase accuracy
  SI.EnthalpyFlowRate H_flow_rear = (if m_flow_rear >= 0 then Medium.specificEnthalpy(state_in_rear) else h_out) * m_flow_rear;
  SI.EnthalpyFlowRate H_flow_fore = (if m_flow_fore >= 0 then Medium.specificEnthalpy(state_in_fore) else h_out) * m_flow_fore;
  SI.MassFlowRate Xi_flow_rear[Medium.nXi] = (if m_flow_rear >= 0 then Medium.massFraction(state_in_rear) else Xi_out) * m_flow_rear;
  SI.MassFlowRate Xi_flow_fore[Medium.nXi] = (if m_flow_fore >= 0 then Medium.massFraction(state_in_fore) else Xi_out) * m_flow_fore;

  Medium.ThermodynamicState state_out;
  SI.SpecificEnthalpy h_out = Medium.specificEnthalpy(state_out);
  Medium.MassFraction Xi_out[Medium.nXi] = Medium.massFraction(state_out);
  SI.Pressure p_out = Medium.pressure(state_out);

  Real d(unit="1/(m.s)") = k_volume_damping*sqrt(abs(2*L/(V*max(density_derp_h, 1e-10)))) "Friction factor for coupled boundaries";
  SI.DerDensityByPressure density_derp_h "Partial derivative of density by pressure";
  SI.Pressure r_damping = d*der(M);

  SI.Pressure r_rear_port, r_fore_port;
  SI.MassFlowRate m_flow_rear, m_flow_fore;
  Medium.ThermodynamicState state_in_rear, state_in_fore;

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
  der(m_flow_rear)*L = r_rear_port - r_rear_intern - r_damping;
  der(m_flow_fore)*L = r_fore_port - r_fore_intern - r_damping;

  der(M) = m_flow_rear + m_flow_fore;
  der(U_med) = Q_flow +H_flow_rear + H_flow_fore;
  der(MXi) = Xi_flow_rear + Xi_flow_fore;

  Q_flow = U*A*(T_heatPort - medium.T);

  if not useHeatport then
    T_heatPort = medium.T;
  end if;
  if not useRear then
    m_flow_rear = 0;
    state_in_rear = Medium.setState_phX(Medium.p_default,  Medium.h_default, Medium.X_default[1:Medium.nXi]);
    end if;
  if not useFore then
    m_flow_fore = 0;
    state_in_fore = Medium.setState_phX(Medium.p_default, Medium.h_default, Medium.X_default[1:Medium.nXi]);
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
<p>This is the partial parent class for all bidirectional volumes with only one fore and rear. It is partial and is missing one equation for its volume or medium pressure and one for the volume work performed.</p>
<p>Conceptually a Volume is a Sink and a Source. It therefore defines the Level of inertial pressure r in a closed loop and acts as a Loop breaker.</p>
<p>Volumes implement a damping term on the change of the stored mass to dampen out fast, otherwise undamped oscillations that appear when connecting volumes directly to other volumes or other boundaries (source, sink, boundary_fore, boundary_rear). With the damping term these oscillations will be still very fast, but dampeend out, so a stiff solver might be able to handle them well. Damping is enabled by default and can be disabled by setting Advanced.k_volume_damping=0. </p>
</html>"));
end PartialVolume;
