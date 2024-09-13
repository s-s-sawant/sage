r"""
Tropical Varieties

A tropical variety is a piecewise-linear geometric object derived from
a classical algebraic variety by using tropical mathematics, where the
tropical semiring replaces the usual arithmetic operations.

AUTHORS:

- Verrel Rievaldo Wijaya (2024-06): initial version

REFERENCES:

- [Bru2014]_
- [Fil2017]_
"""

# ****************************************************************************
#       Copyright (C) 2024 Verrel Rievaldo Wijaya <verrelrievaldo@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  https://www.gnu.org/licenses/
# ****************************************************************************

from sage.structure.sage_object import SageObject
from sage.rings.infinity import infinity
from sage.structure.unique_representation import UniqueRepresentation

class TropicalVariety(UniqueRepresentation, SageObject):
    r"""
    A tropical variety in `\RR^n`.

    A tropical variety is defined as a corner locus of tropical polynomial
    function. This means it consist of all points in `\RR^n` for which
    the minimum (maximum) of the function is attained at least twice.

    We represent the tropical variety as a list of lists, where the
    inner list consist of three parts. The first one is a parametric
    equations for tropical roots. The second one is the condition
    for parameters. The third one is the order of the corresponding
    component.

    INPUT:

    - ``poly`` -- a :class:`TropicalMPolynomial`

    ALGORITHM:

    We need to determine a corner locus of this tropical polynomial
    function, which is all points `(x_1, x_2, \ldots, x_n)` for which
    the maximum (minimum) is obtained at least twice. First, we convert
    each monomial to its corresponding linear function. Then for each two
    monomials of polynomial, we find the points where their values are
    equal. Since we attempt to solve the equality of two equations in `n`
    variables, the solution set will be described by `n-1` parameters.

    Next, we need to check if the value of previous two monomials at the
    points in solution set is really the maximum (minimum) of function.
    We do this by solving the inequality of the previous monomial with all
    other monomials in the polynomial after substituting the parameter.
    This will give us the condition of parameters. Each of this condition
    is then combined by union operator. If this final condition is not an
    empty set, then it represent one component of tropical root. Then we
    calculate the weight of this particular component by the maximum of
    gcd of the numbers `|i-k|` and `|j-l|` for all pairs `(i,j)` and
    `(k,l)` such that the value of on this component is given by the
    corresponding monomials.

    EXAMPLES:

    We construct a tropical variety in `\RR^2`, where it is called a
    tropical curve::

        sage: T = TropicalSemiring(QQ, use_min=False)
        sage: R.<x,y> = PolynomialRing(T)
        sage: p1 = R(1)*x + x*y + R(0); p1
        0*x*y + 1*x + 0
        sage: tv = p1.tropical_variety(); tv
        Tropical curve of 0*x*y + 1*x + 0
        sage: tv.components()
        [[(t1, 1), [t1 >= -1], 1], [(-1, t1), [t1 <= 1], 1], [(-t1, t1), [t1 >= 1], 1]]
        sage: tv.vertices()
        {(-1, 1)}
        sage: tv.plot()
        Graphics object consisting of 3 graphics primitives

    .. PLOT::
        :width: 300 px

        T = TropicalSemiring(QQ, use_min=False)
        R = PolynomialRing(T, ('x,y'))
        x, y = R.gen(), R.gen(1)
        p1 = R(1)*x + x*y + R(0)
        sphinx_plot(p1.tropical_variety().plot())

    A slightly different result will be obtained if we use min-plus algebra
    for the base tropical semiring::

        sage: T = TropicalSemiring(QQ, use_min=True)
        sage: R.<x,y> = PolynomialRing(T)
        sage: p1 = R(1)*x + x*y + R(0)
        sage: tv = p1.tropical_variety(); tv
        Tropical curve of 0*x*y + 1*x + 0
        sage: tv.components()
        [[(t1, 1), [t1 <= -1], 1], [(-1, t1), [t1 >= 1], 1], [(-t1, t1), [t1 <= 1], 1]]
        sage: tv.plot()
        Graphics object consisting of 3 graphics primitives

    .. PLOT::
        :width: 300 px

        T = TropicalSemiring(QQ, use_min=True)
        R = PolynomialRing(T, ('x,y'))
        x, y = R.gen(), R.gen(1)
        p1 = R(1)*x + x*y + R(0)
        sphinx_plot(p1.tropical_variety().plot())

    Tropical variety can consist of multiple components with varying orders::

        sage: T = TropicalSemiring(QQ, use_min=False)
        sage: R.<x,y> = PolynomialRing(T)
        sage: p1 = R(7) + T(4)*x + y + R(4)*x*y + R(3)*y^2 + R(-3)*x^2
        sage: tv = p1.tropical_variety(); tv
        Tropical curve of (-3)*x^2 + 4*x*y + 3*y^2 + 4*x + 0*y + 7
        sage: tv.components()
        [[(3, t1), [t1 <= 0], 1],
        [(-t1 + 3, t1), [0 <= t1, t1 <= 2], 1],
        [(t1, 2), [t1 <= 1], 2],
        [(t1, 0), [3 <= t1, t1 <= 7], 1],
        [(7, t1), [t1 <= 0], 1],
        [(t1 - 1, t1), [2 <= t1], 1],
        [(t1 + 7, t1), [0 <= t1], 1]]
        sage: tv.plot()
        Graphics object consisting of 8 graphics primitives

    .. PLOT::
        :width: 300 px

        T = TropicalSemiring(QQ, use_min=False)
        R = PolynomialRing(T, ('x,y'))
        x, y = R.gen(), R.gen(1)
        p1 = R(7) + T(4)*x + y + R(4)*x*y + R(3)*y**2 + R(-3)*x**2
        sphinx_plot(p1.tropical_variety().plot())

    If the tropical polynomial have `n>2` variables, then the result will be
    a tropical hypersurface embedded in a real space `\RR^n`::

        sage: T = TropicalSemiring(QQ)
        sage: R.<a,x,y,z> = PolynomialRing(T)
        sage: p1 = x*y + R(-1/2)*x*z + R(4)*z^2 + a*x
        sage: tv = p1.tropical_variety(); tv
        Tropical hypersurface of 0*a*x + 0*x*y + (-1/2)*x*z + 4*z^2
        sage: tv.components()
        [[(t1, t2, t3 - 1/2, t3), [t2 - 9/2 <= t3, t3 <= t1 + 1/2, t2 - 5 <= t1], 1],
        [(t1, 2*t2 - t3 + 4, t3, t2), [t3 + 1/2 <= t2, t3 <= t1], 1],
        [(t1, t2, t1, t3), [max(t1 + 1/2, 1/2*t1 + 1/2*t2 - 2) <= t3], 1],
        [(t1, t2 + 9/2, t3, t2), [t2 <= min(t3 + 1/2, t1 + 1/2)], 1],
        [(t1 - 1/2, t2, t3, t1), [t2 - 9/2 <= t1, t1 <= t3 + 1/2, t2 - 5 <= t3], 1],
        [(2*t1 - t2 + 4, t2, t3, t1), [t1 <= min(1/2*t2 + 1/2*t3 - 2, t2 - 9/2)], 1]]
    """
    def __init__(self, poly):
        r"""
        Initialize ``self``.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y> = PolynomialRing(T)
            sage: tv = (x+y).tropical_variety()
            sage: TestSuite(tv).run()

        TESTS::

            sage: from sage.rings.semirings.tropical_variety import TropicalVariety
            sage: R.<x,y> = QQ[]
            sage: p1 = x + y
            sage: TropicalVariety(p1)
            Traceback (most recent call last):
            ...
            ValueError: x + y is not a multivariate tropical polynomial
        """
        import operator
        from itertools import combinations
        from sage.symbolic.ring import SR
        from sage.symbolic.relation import solve
        from sage.arith.misc import gcd
        from sage.rings.semirings.tropical_mpolynomial import TropicalMPolynomial

        if not isinstance(poly, TropicalMPolynomial):
            raise ValueError(f"{poly} is not a multivariate tropical polynomial")

        self._poly = poly
        self._hypersurface = []
        tropical_roots = []
        variables = []
        for name in poly.parent().variable_names():
            variables.append(SR.var(name))

        # Convert each term to its linear function
        linear_eq = {}
        pd = poly.dict()
        for key in pd:
            eq = sum(variables[i] * e for i, e in enumerate(key))
            eq += pd[key].lift()
            linear_eq[key] = eq
        temp_keys = []
        temp_order = []

        # Checking for all possible combinations of two terms
        for keys in combinations(pd, 2):
            sol = solve(linear_eq[keys[0]] == linear_eq[keys[1]], variables)

            # Parametric solution of the chosen two terms
            final_sol = []
            for s in sol[0]:
                final_sol.append(s.right())
            xy_interval = []
            xy_interval.append(tuple(final_sol))

            # Comparing with other terms
            min_max = linear_eq[keys[0]]
            for i, v in enumerate(variables):
                min_max = min_max.subs(**{str(v): final_sol[i]})
            all_sol_compare = []
            no_solution = False
            for compare in pd:
                if compare not in keys:
                    temp_compare = linear_eq[compare]
                    for i, v in enumerate(variables):
                        temp_compare = temp_compare.subs(**{str(v): final_sol[i]})
                    if min_max == temp_compare:
                        sol_compare = [[]]
                    elif poly.parent().base()._use_min:
                        sol_compare = solve(min_max < temp_compare, variables)
                    else:
                        sol_compare = solve(min_max > temp_compare, variables)
                    if sol_compare:
                        if isinstance(sol_compare[0], list):
                            if sol_compare[0]:
                                all_sol_compare.append(sol_compare[0][0])
                        else:  # solution is unbounded on one side
                            all_sol_compare.append(sol_compare[0])
                    else:
                        no_solution = True
                        break

            # Solve the condition for parameter
            if not no_solution:
                parameter = set()
                for sol in all_sol_compare:
                    parameter = parameter.union(set(sol.variables()))
                parameter_solution = solve(all_sol_compare, list(parameter))
                if parameter_solution:
                    xy_interval.append(parameter_solution[0])
                    tropical_roots.append(xy_interval)
                    # Calculate the order
                    index_diff = []
                    for i in range(len(keys[0])):
                        index_diff.append(abs(keys[0][i] - keys[1][i]))
                    order = gcd(index_diff)
                    temp_order.append(order)
                    temp_keys.append(keys)

        # Changing all the operator symbol to be <= or >=
        self._keys = []
        components = []
        dim_param = 0
        if tropical_roots:
            dim_param = len(tropical_roots[0][0]) - 1
        vars = [SR.var('t{}'.format(i)) for i in range(1, dim_param+1)]
        for arg in tropical_roots:
            subs_dict = {}
            index_vars = 0
            new_eq = []
            for eq in arg[0]:
                var_eq = eq.variables()
                for var in var_eq:
                    if var not in subs_dict:
                        subs_dict[var] = vars[index_vars]
                        index_vars += 1
                new_eq.append(eq.subs(subs_dict))
            new_eq = tuple(new_eq)
            arg.remove(arg[0])
            arg.insert(0, new_eq)
            if not arg[1] or not isinstance(arg[1], list):
                arg[1] = []
                for var in vars:
                    expr1 = -infinity < var
                    expr2 = var < infinity
                    arg[1].append(expr1)
                    arg[1].append(expr2)
            else:
                params = arg[1]
                arg.remove(params)
                new_param = []
                for param in params:
                    lhs = param.lhs().subs(subs_dict)
                    rhs = param.rhs().subs(subs_dict)
                    if param.operator() == operator.gt:
                        expr = lhs >= rhs
                    else:
                        expr = lhs <= rhs
                    new_param.append(expr)
                arg.insert(1, new_param)
            components.append(arg)

        # Determine the order of each component
        self._vars = vars
        final_order = []
        for i, component in enumerate(components):
            if component not in self._hypersurface:
                self._hypersurface.append(component)
                final_order.append(temp_order[i])
                self._keys.append(temp_keys[i])
            else:
                index = self._hypersurface.index(component)
                if temp_order[i] > final_order[index]:
                    final_order[index] = temp_order[i]
                    self._keys[index] = temp_keys[i]
        for i in range(len(self._hypersurface)):
            self._hypersurface[i].append(final_order[i])

    def dimension(self):
        """
        Return the dimension of ``self``.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<a,x,y,z> = PolynomialRing(T)
            sage: p1 = x*y + R(-1)*x*z
            sage: p1.tropical_variety().dimension()
            4
        """
        return self._poly.parent().ngens()

    def number_of_components(self):
        """
        Return the number of components that make up ``self``.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<a,x,y,z> = PolynomialRing(T)
            sage: p1 = x*y*a + x*z + y^2 + a*x + y + z
            sage: p1.tropical_variety().number_of_components()
            13
        """
        from sage.rings.integer_ring import ZZ
        return ZZ(len(self._hypersurface))

    def _repr_(self):
        """
        Return a string representation of ``self``.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<w,x,y,z> = PolynomialRing(T)
            sage: (w).tropical_variety()
            Tropical hypersurface of 0*w
        """
        return f"Tropical hypersurface of {self._poly}"

    def _latex_(self):
        r"""
        Return a latex representation of ``self``.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<w,x,y,z> = PolynomialRing(T)
            sage: tv = (R(1)*w^2 + x*y*z + R(-1)).tropical_variety()
            sage: latex(tv)
            TV\left(0 x y z + 1 w^{2} + \left(-1\right)\right)
        """
        return f"TV\\left({self._poly._latex_()}\\right)"

    def components(self):
        """
        Return all components of ``self``.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<a,x,y,z> = PolynomialRing(T)
            sage: tv = (a+x+y+z).tropical_variety()
            sage: tv.components()
            [[(t1, t1, t2, t3), [t1 <= min(t3, t2)], 1],
             [(t1, t2, t1, t3), [t1 <= t3, t1 <= t2], 1],
             [(t1, t2, t3, t1), [t1 <= min(t3, t2)], 1],
             [(t1, t2, t2, t3), [t2 <= t3, t2 <= t1], 1],
             [(t1, t2, t3, t2), [t2 <= min(t3, t1)], 1],
             [(t1, t2, t3, t3), [t3 <= min(t1, t2)], 1]]
        """
        return self._hypersurface

    def _components_intersection(self):
        r"""
        Return the intersection of three or more components of ``self``.

        For a tropical variety in `\RR^n`, the intersection is characterized
        by a linear equation in `\RR^{n-1}`. Specifically, this becomes a
        vertex for tropical curve and an edges for tropical surface.

        OUTPUT:

        A dictionary where the keys represent component indices and the
        values are lists of tuples. Each tuple contains a parametric
        equation of points and the corresponding parameter's condition.

        EXAMPLES:

        In two dimension, it will provide vertices that are incident with
        each component::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y> = PolynomialRing(T)
            sage: p1 = R(2)*x^2 + x*y + R(2)*y^2 + x + R(-1)*y + R(3)
            sage: tv = p1.tropical_variety()
            sage: tv._components_intersection()
            {0: [((-2, 0), {})],
            1: [((-2, 0), {})],
            2: [((-1, -3), {})],
            3: [((-2, 0), {}), ((-1, 0), {})],
            4: [((-1, -3), {}), ((-1, 0), {})],
            5: [((-1, -3), {})],
            6: [((-1, 0), {}), ((3, 4), {})],
            7: [((3, 4), {})],
            8: [((3, 4), {})]}

        In three dimensions, it will provide all parametric equations of
        lines that lie within each component::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y,z> = PolynomialRing(T)
            sage: p1 = x + y + z + x^2
            sage: tv = p1.tropical_variety()
            sage: tv._components_intersection()
            {0: [((t2, t2, t2), {0 <= t2}), ((0, 0, t2), {0 <= t2})],
            1: [((0, t2, 0), {0 <= t2}), ((t2, t2, t2), {0 <= t2})],
            2: [((0, t1, 0), {0 <= t1}), ((0, 0, t2), {0 <= t2})],
            3: [((t1, t1, t1), {0 <= t1}), ((t1, 2*t1, 2*t1), {t1 <= 0})],
            4: [((1/2*t2, t2, t2), {t2 <= 0}), ((0, 0, t2), {0 <= t2})],
            5: [((0, t2, 0), {0 <= t2}), ((1/2*t2, t2, t2), {t2 <= 0})]}
        """
        import operator
        from sage.functions.min_max import max_symbolic, min_symbolic
        from sage.symbolic.relation import solve
        from sage.symbolic.expression import Expression
        from sage.sets.set import Set

        def update_result(result):
            sol_param = solve(new_expr, vars)
            sol_param_sim = set()
            for sol in sol_param:
                if sol == []:
                    for v in vars:
                        if v != var:
                            sol_param_sim.add(v < infinity)
                elif isinstance(sol, list):
                    for eqn in sol:
                        if eqn.operator() == operator.eq:
                            if not eqn.rhs().is_numeric():
                                eqn_var = eqn.rhs().variables()
                                param_var = [v for v in eqn_var if v in vars]
                                if not param_var:
                                    v = eqn.lhs()
                                    if v != var:
                                        sol_param_sim.add(v < infinity)
                        elif eqn.operator() == operator.lt:
                            sol_param_sim.add(eqn.lhs() <= eqn.rhs())
                        elif eqn.operator() == operator.gt:
                            sol_param_sim.add(eqn.lhs() >= eqn.rhs())
                else:
                    sol_param_sim.add(sol)
            # Checking there are no conditions with the same variables
            # that use the <= and >= operators simultaneously
            unique_sol_param = set()
            temp = [s for s in sol_param_sim]
            op_temp = {i: set(temp[i].operands()) for i in range(len(temp))}
            for s_value in op_temp.values():
                match_keys = [k for k, v in op_temp.items() if v == s_value]
                if len(match_keys) == 1:
                    for i in match_keys:
                        unique_sol_param.add(temp[i])

            if (unique_sol_param) or (self.dimension() == 2):
                if not unique_sol_param:
                    unique_sol_param = Set()
                if index not in result:
                    result[index] = [(tuple(points), unique_sol_param)]
                else:
                    result[index].append((tuple(points), unique_sol_param))

        result = {}
        vars = self._vars
        for index, comp in enumerate(self._hypersurface):
            for expr in comp[1]:
                left = expr.lhs()
                right = expr.rhs()
                # If the lhs contains a min or max operator
                if (left.operator() == max_symbolic) or (left.operator() == min_symbolic):
                    for operand in expr.lhs().operands():
                        points = list(comp[0])
                        new_expr = [e.subs(**{str(right): operand}) for e in comp[1]]
                        for i, p in enumerate(points):
                            new_eq = p.subs(**{str(right): operand})
                            points[i] = new_eq
                        update_result(result)
                # If the rhs contains a min or max operator
                elif (right.operator() == max_symbolic) or (right.operator() == min_symbolic):
                    for operand in expr.rhs().operands():
                        points = list(comp[0])
                        new_expr = [e.subs(**{str(left): operand}) for e in comp[1]]
                        for i, p in enumerate(points):
                            new_eq = p.subs(**{str(left): operand})
                            points[i] = new_eq
                        update_result(result)
                else:
                    var = expr.variables()[0]
                    points = list(comp[0])
                    subs_expr = solve(left == right, var)[0].rhs()
                    new_expr = [e.subs(**{str(var): subs_expr}) for e in comp[1]]
                    for i, p in enumerate(points):
                        new_eq = p.subs(**{str(var): subs_expr})
                        points[i] = new_eq
                    update_result(result)
        return result


class TropicalSurface(TropicalVariety):
    r"""
    A tropical surface in `\RR^3`.

    The tropical surface consists of planar regions and facets, which we
    can call cells. These cells are connected in such a way that they form
    a piecewise linear structure embedded in three-dimensional space. These
    cells meet along edges, where the balancing condition is satisfied.
    This balancing condition ensures that the sum of the outgoing normal
    vectors at each edge is zero, reflecting the equilibrium.

    EXAMPLES::

        sage: T = TropicalSemiring(QQ, use_min=False)
        sage: R.<x,y,z> = PolynomialRing(T)
        sage: p1 = x + y + z + R(0)
        sage: tv = p1.tropical_variety(); tv
        Tropical surface of 0*x + 0*y + 0*z + 0
        sage: tv.components()
        [[(t1, t1, t2), [t2 <= t1, 0 <= t1], 1],
        [(t1, t2, t1), [max(0, t2) <= t1], 1],
        [(0, t1, t2), [t2 <= 0, t1 <= 0], 1],
        [(t1, t2, t2), [max(0, t1) <= t2], 1],
        [(t1, 0, t2), [t2 <= 0, t1 <= 0], 1],
        [(t1, t2, 0), [t1 <= 0, t2 <= 0], 1]]
    """
    def _axes(self):
        r"""
        Set the default axes for ``self``.

        This default axes is used for the 3d plot. The axes is centered
        around where the intersection of the components occured so it
        gives a nice visual representation for the interactions between
        different components of the surface. Additionally, it enhances
        the visibility and interpretation of how the components align
        and interact in three-dimensional space.

        OUTPUT:

        A list of three lists, where the first inner list represent value
        of x-axis, the second inner list represent value of y-axis, and
        the third inner list represent value of z-axis. If there are
        either no components or only one component, the axis will be set
        to `[[-1, 1], [-1, 1], [-1, 1]]`.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y,z> = PolynomialRing(T)
            sage: p1 = x
            sage: p1.tropical_variety()._axes()
            [[-1, 1], [-1, 1], [-1, 1]]
            sage: p2 = x + y + z + x^2 + R(1)
            sage: p2.tropical_variety()._axes()
            [[-1, 2], [-1, 2], [-1, 2]]
        """
        from sage.symbolic.relation import solve
        from sage.arith.srange import srange

        if not self._hypersurface:
            return [[-1, 1], [-1, 1], [-1, 1]]
        elif len(self._hypersurface) == 1:
            bound = 1
            for eqn in self._hypersurface[0][0]:
                for op in eqn.operands():
                    if op.is_numeric():
                        if op > bound:
                            bound = op
            return [[-bound, bound]] * 3

        u_set = set()
        v_set = set()
        for comp in self._hypersurface:
            list_expr = []
            temp_u = set()
            temp_v = set()
            for expr in comp[1]:
                if expr.lhs().is_numeric():
                    if bool(expr.rhs() == self._vars[0]):
                        temp_u.add(expr.lhs())
                    else:
                        temp_v.add(expr.lhs())
                elif expr.rhs().is_numeric():
                    if bool(expr.lhs() == self._vars[0]):
                        temp_u.add(expr.rhs())
                    else:
                        temp_v.add(expr.rhs())
                else:
                    list_expr.append(expr)
            if not temp_u:
                temp_u.add(0)
            if not temp_v:
                temp_v.add(0)
            for expr in list_expr:
                for u in temp_u:
                    sol = solve(expr.subs(**{str(self._vars[0]): u}), self._vars[1])
                    if not sol:
                        temp_v.add(0)
                    elif not sol[0]:
                        temp_v.add(0)
                    else:
                        temp_v.add(sol[0][0].rhs())
                for v in temp_v:
                    sol = solve(expr.subs(**{str(self._vars[1]): v}), self._vars[0])
                    if not sol:
                        temp_u.add(0)
                    elif not sol[0]:
                        temp_u.add(0)
                    else:
                        temp_u.add(sol[0][0].rhs())
            u_set = u_set.union(temp_u)
            v_set = v_set.union(temp_v)
        axes = [[min(u_set)-1, max(u_set)+1], [min(v_set)-1, max(v_set)+1]]

        # Finding the z-axis
        step = 10
        du = (axes[0][1]-axes[0][0]) / step
        dv = (axes[1][1]-axes[1][0]) / step
        u_range = srange(axes[0][0], axes[0][1]+du, du)
        v_range = srange(axes[1][0], axes[1][1]+dv, dv)
        zmin, zmax = None, None
        for comp in self._hypersurface:
            for u in u_range:
                for v in v_range:
                    checkpoint = True
                    for exp in comp[1]:
                        final_exp = exp.subs(**{str(self._vars[0]): u, str(self._vars[1]): v})
                        if not final_exp:
                            checkpoint = False
                            break
                    if checkpoint:
                        z = comp[0][2].subs(**{str(self._vars[0]): u, str(self._vars[1]): v})
                        if (zmin is None) and (zmax is None):
                            zmin = z
                            zmax = z
                        else:
                            if z < zmin:
                                zmin = z
                            if z > zmax:
                                zmax = z
        axes.append([zmin, zmax])
        return axes

    def _polygon_vertices(self):
        r"""
        Return the vertices of the polygon for each components of ``self``
        to be used for plotting.

        OUTPUT:

        A dictionary where the keys represent component indices and the
        values are a set of points in three dimensional space.

        EXAMPLES:

        A tropical surface with only one component::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y,z> = PolynomialRing(T)
            sage: p1 = x + z
            sage: tv1 = p1.tropical_variety()
            sage: tv1._polygon_vertices()
            {0: {(-1, -1, -1), (-1, 1, -1), (1, -1, 1), (1, 1, 1)}}

        A tropical surface with multiple components::

            sage: p2 = x^2 + x + y + z + R(1)
            sage: tv2 = p2.tropical_variety()
            sage: tv2._polygon_vertices()
            {0: {(0, 0, 0), (0, 0, 2), (1, 1, 1), (2, 2, 2)},
            1: {(0, 0, 0), (0, 2, 0), (1, 1, 1), (2, 2, 2)},
            2: {(0, 0, 0), (0, 0, 2), (0, 2, 0), (0, 2, 2)},
            3: {(1, 1, 1), (1, 1, 2), (1, 2, 1), (1, 2, 2)},
            4: {(-1/2, -1, -1), (0, 0, 0), (1, 1, 1), (2, -1, -1), (2, 1, 1)},
            5: {(-1/2, -1, -1), (-1/2, -1, 2), (0, 0, 0), (0, 0, 2)},
            6: {(1, 1, 1), (1, 1, 2), (2, 1, 1), (2, 1, 2)},
            7: {(-1/2, -1, -1), (-1/2, 2, -1), (0, 0, 0), (0, 2, 0)},
            8: {(1, 1, 1), (1, 2, 1), (2, 1, 1), (2, 2, 1)}}
        """
        from sage.sets.real_set import RealSet
        from sage.symbolic.relation import solve
        from sage.rings.rational_field import QQ

        poly_verts = {i: set() for i in range(self.number_of_components())}
        axes = self._axes()
        comps = self.components()
        vars = self._vars
        comps_int = self._components_intersection()

        # Finding the inside vertices
        for index, lines in comps_int.items():
            for line in lines:
                v = list(line[1])[0].variables()[0]
                for param in line[1]:
                    left = param.lhs()
                    right = param.rhs()
                    if left.is_numeric():
                        vertex = [QQ(e.subs(**{str(v): left})) for e in line[0]]
                        poly_verts[index].add(tuple(vertex))
                    elif right.is_numeric():
                        vertex = [QQ(e.subs(**{str(v): right})) for e in line[0]]
                        poly_verts[index].add(tuple(vertex))

        def find_edge_vertices(i):
            j = (i+1) % 2
            if i == 0:  # interval for t1
                interval = interval1
            else:  # interval for t2
                interval = interval2
            for p in [interval.inf(), interval.sup()]:
                new_param = [e.subs(**{str(vars[i]): p}) for e in comps[index][1]]
                sol = solve(new_param, vars[j])
                if sol:
                    interval_param = RealSet()
                    for s in sol:
                        if s != []:
                            # Handle cases where 's' is not a list (s = r1 < +Infinity),
                            # or if 's' is a list, ensure that its elements define a real
                            # interval (catch invalid cases like s = [t1 == r100]).
                            try:
                                interval_param += RealSet(s[0])
                            except (IndexError, ValueError):
                                interval_param += RealSet(-infinity, infinity)
                        else:
                            interval_param += RealSet(-infinity, infinity)
                    interval_param = interval_param.intersection(interval2)
                    if is_doublevar:
                        int1 = RealSet()
                        for s1 in sol1:
                            subs1 = solve(s1[0].subs(**{str(vars[i]): p}), vars[j])
                            try:
                                int1 += RealSet(subs1[0])
                            except TypeError:
                                int1 += RealSet(subs1[0][0])
                        int2 = RealSet()
                        for s2 in sol2:
                            subs2 = solve(s2[0].subs(**{str(vars[i]): p}), vars[j])
                            try:
                                int2 += RealSet(subs2[0])
                            except TypeError:
                                int2 += RealSet(subs2[0][0])
                        final_int = int1.intersection(int2)
                        interval_param = interval_param.intersection(final_int)
                    if interval_param:
                        vertex1 = [QQ(e.subs(**{str(vars[i]): p, str(vars[j]): interval_param.inf()})) for e in comps[index][0]]
                        vertex2 = [QQ(e.subs(**{str(vars[i]): p, str(vars[j]): interval_param.sup()})) for e in comps[index][0]]
                        poly_verts[index].add(tuple(vertex1))
                        poly_verts[index].add(tuple(vertex2))

        # Find the interval of parameter for outer vertex
        for index in range(len(comps)):
            interval1 = RealSet(-infinity,infinity)  # represent t1
            interval2 = RealSet(-infinity,infinity)  # represent t2
            is_doublevar = False
            for i, point in enumerate(comps[index][0]):
                pv = point.variables()
                if len(pv) == 1:
                    temp1 = RealSet(solve(point >= axes[i][0], pv[0])[0][0])
                    temp2 = RealSet(solve(point <= axes[i][1], pv[0])[0][0])
                    temp = temp1.intersection(temp2)
                    if pv[0] == vars[0]:
                        interval1 = interval1.intersection(temp)
                    else:
                        interval2 = interval2.intersection(temp)
                elif len(pv) == 2:
                    sol1 = solve(point >= axes[i][0], pv)
                    sol2 = solve(point <= axes[i][1], pv)
                    is_doublevar = True
            # Finding the edge vertices (those that touch the axes)
            find_edge_vertices(0)  # t1 fixed
            find_edge_vertices(1)  # t2 fixed
        return poly_verts

    def plot(self, color='random'):
        """
        Return the plot of ``self`` by constructing a polyhedron from
        vertices in ``self.polygon_vertices()``.

        INPUT:

        - ``color`` -- string or tuple that represent a color (default:
          ``random``); ``random`` means each polygon will be assigned
          a different color. If instead a specific ``color`` is provided,
          then all polygon will be given the same color.

        OUTPUT: Graphics3d Object

        EXAMPLES:

        A tropical surface that consist of only one cell::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y,z> = PolynomialRing(T)
            sage: p1 = x + z
            sage: tv = p1.tropical_variety()
            sage: tv.plot()
            Graphics3d Object

        .. PLOT::
            :width: 300 px

            T = TropicalSemiring(QQ)
            R = PolynomialRing(T, ('x,y,z'))
            x, y, z = R.gen(), R.gen(1), R.gen(2)
            p1 = x + z
            sphinx_plot(p1.tropical_variety().plot())

        A tropical surface with multiple cell that exhibit complex and
        intriguing geometric structures::

            sage: p2 = x^2 + x + y + z + R(1)
            sage: tv = p2.tropical_variety()
            sage: tv.plot()
            Graphics3d Object

        .. PLOT::
            :width: 300 px

            T = TropicalSemiring(QQ)
            R = PolynomialRing(T, ('x,y,z'))
            x, y, z = R.gen(), R.gen(1), R.gen(2)
            p2 = x**2 + x + y + z + R(1)
            sphinx_plot(p2.tropical_variety().plot())
        """
        from random import random
        from sage.plot.graphics import Graphics
        from sage.geometry.polyhedron.constructor import Polyhedron

        if color == 'random':
            colors = []
            for _ in range(self.number_of_components()):
                color = (random(), random(), random())
                colors.append(color)
        elif isinstance(color, str):
            colors = [color] * self.number_of_components()
        else:
            colors = color

        combined_plot = Graphics()
        for i, vertex in self._polygon_vertices().items():
            points = list(vertex)
            plot = Polyhedron(vertices=points).plot(color=colors[i])
            combined_plot += plot
        return combined_plot

    def _repr_(self):
        """
        Return a string representation of ``self``.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y,z> = PolynomialRing(T)
            sage: (x^4+z^2).tropical_variety()
            Tropical surface of 0*x^4 + 0*z^2
        """
        return f"Tropical surface of {self._poly}"


class TropicalCurve(TropicalVariety):
    r"""
    A tropical curve in `\RR^2`.

    The tropical curve consists of line segments and half-lines, which we
    call edges. These edges are connected in such a way that they form a
    piecewise linear graph embedded in the plane. These edges meet at
    a vertices, where the balancing condition is satisfied. This balancing
    condition ensures that the sum of the outgoing slopes at each vertex
    is zero, reflecting the equilibrium.

    EXAMPLES::

        sage: T = TropicalSemiring(QQ, use_min=False)
        sage: R.<x,y> = PolynomialRing(T)
        sage: p1 = x + y + R(0)
        sage: tv = p1.tropical_variety(); tv
        Tropical curve of 0*x + 0*y + 0
        sage: tv.components()
        [[(t1, t1), [t1 >= 0], 1], [(0, t1), [t1 <= 0], 1], [(t1, 0), [t1 <= 0], 1]]
    """
    def _axes(self):
        """
        Set the default axes for ``self``.

        This default axes is used for plot of tropical curve and also the
        3d plot of tropical polynomial function. The axes is chosen by first
        find all vertices of this tropical curve. Then we choose the minimum
        and maximum of all x-component in this vertices to be the x-axis.
        The same apply to the y-axis.

        OUTPUT:

        A list of two lists, where the first inner list represent value of
        x-axis and the second inner list represent value of y-axis.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y> = PolynomialRing(T)
            sage: p1 = x^2
            sage: p1.tropical_variety()._axes()
            [[-1, 1], [-1, 1]]
            sage: p2 = R(12)*x*y + R(-2)*y^2 + R(16)*y + R(25)
            sage: p2.tropical_variety()._axes()
            [[-3/2, 1/2], [25/2, 29/2]]
        """
        if self.number_of_components() == 0:
            return [[-1, 1], [-1, 1]]
        if self.number_of_components() <= 2:
            bound = 1
            for comps in self._hypersurface:
                eqns = comps[0]
                temp_operands = []
                for eq in eqns:
                    if not eq.operator():
                        temp_operands.append(eq)
                    else:
                        temp_operands += eq.operands()
                for op in temp_operands:
                    if op.is_numeric():
                        if abs(op) > bound:
                            bound = abs(op)
            return [[-bound, bound]] * 2

        verts = self.vertices()
        xmin = xmax = list(verts)[0][0]
        for vertex in verts:
            if vertex[0] < xmin:
                xmin = vertex[0]
            elif vertex[0] > xmax:
                xmax = vertex[0]
        ymin = ymax = list(verts)[0][1]
        for vertex in verts:
            if vertex[1] < ymin:
                ymin = vertex[1]
            elif vertex[1] > ymax:
                ymax = vertex[1]
        return [[xmin-1, xmax+1], [ymin-1, ymax+1]]

    def vertices(self):
        r"""
        Return all vertices of ``self``, which is the point where three or
        more edges intersect.

        OUTPUT: A set of `(x,y)` points

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y> = PolynomialRing(T)
            sage: p1 = x + y
            sage: p1.tropical_variety().vertices()
            set()
            sage: p2 = R(-2)*x^2 + R(-1)*x + R(1/2)*y + R(1/6)
            sage: p2.tropical_variety().vertices()
            {(1, -1/2), (7/6, -1/3)}
        """
        if len(self._hypersurface) < 3:
            return set()

        vertices = set()
        for i, component in enumerate(self._hypersurface):
            parametric_function = component[0]
            var = component[1][0].variables()[0]
            interval = self._parameter_intervals()[i]
            lower = interval[0].lower()
            upper = interval[0].upper()
            if lower != -infinity:
                x = parametric_function[0].subs(**{str(var): lower})
                y = parametric_function[1].subs(**{str(var): lower})
                vertices.add((x,y))
            if upper != infinity:
                x = parametric_function[0].subs(**{str(var): upper})
                y = parametric_function[1].subs(**{str(var): upper})
                vertices.add((x,y))
        return vertices

    def _parameter_intervals(self):
        r"""
        Return the intervals of each component's parameter of ``self``.

        OUTPUT: A list of ``RealSet``

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y> = PolynomialRing(T)
            sage: p1 = y + y^2
            sage: p1.tropical_variety()._parameter_intervals()
            [(-oo, +oo)]
            sage: p2 = x^2 + R(-1)*x*y + R(-1)*x + R(1/3)
            sage: p2.tropical_variety()._parameter_intervals()
            [(-oo, 0], [0, +oo), [-1, 4/3], (-oo, 0], [0, +oo)]
        """
        from sage.sets.real_set import RealSet

        intervals = []
        R = self._poly.parent().base().base_ring()
        for component in self._hypersurface:
            if len(component[1]) == 1:
                interval = RealSet(component[1][0])
            else:
                lower = component[1][0].left()
                upper = component[1][1].right()
                if lower == -infinity:
                    interval = RealSet(-infinity, infinity)
                else:
                    interval = RealSet([R(lower), R(upper)])
            intervals.append(interval)
        return intervals

    def plot(self):
        """
        Return the plot of ``self``.

        Generates a visual representation of the tropical curve in cartesian
        coordinates. The plot shows piecewise-linear segments representing
        each components. The axes are centered around the vertices.

        OUTPUT:

        A Graphics object. The weight of the component will be written if it
        is greater or equal than 2. The weight is written near the vertex.

        EXAMPLES:

        A polynomial with only two terms will give one straight line::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y> = PolynomialRing(T)
            sage: (y+R(1)).tropical_variety().components()
            [[(t1, 1), [-Infinity < t1, t1 < +Infinity], 1]]
            sage: (y+R(1)).tropical_variety().plot()
            Graphics object consisting of 1 graphics primitive

        .. PLOT::
            :width: 300 px

            T = TropicalSemiring(QQ)
            R = PolynomialRing(T, ('x,y'))
            x, y = R.gen(), R.gen(1)
            sphinx_plot((y+R(1)).tropical_variety().plot())

        An intriguing and fascinating tropical curve can be obtained with
        a more complex tropical polynomial::

            sage: p1 = R(1) + R(2)*x + R(3)*y + R(6)*x*y + R(10)*x*y^2
            sage: p1.tropical_variety().components()
            [[(-1, t1), [-2 <= t1], 1],
            [(t1, -2), [-1 <= t1], 1],
            [(t1 + 1, t1), [-4 <= t1, t1 <= -2], 1],
            [(t1, -4), [t1 <= -3], 2],
            [(-t1 - 7, t1), [t1 <= -4], 1]]
            sage: p1.tropical_variety().plot()
            Graphics object consisting of 6 graphics primitives

        .. PLOT::
            :width: 300 px

            T = TropicalSemiring(QQ)
            R = PolynomialRing(T, ('x,y'))
            x, y = R.gen(), R.gen(1)
            p1 = R(1) + R(2)*x + R(3)*y + R(6)*x*y + R(10)*x*y**2
            sphinx_plot(p1.tropical_variety().plot())

        Another tropical polynomial with numerous components, resulting
        in a more intricate structure::

            sage: p2 = (x^6 + R(4)*x^4*y^2 + R(2)*x^3*y^3 + R(3)*x^2*y^4 + x*y^5
            ....:       + R(7)*x^2 + R(5)*x*y + R(3)*y^2 + R(2)*x + y + R(10))
            sage: p2.tropical_variety().plot()
            Graphics object consisting of 11 graphics primitives

        .. PLOT::
            :width: 300 px

            T = TropicalSemiring(QQ)
            R = PolynomialRing(T, ('x,y'))
            x, y = R.gen(), R.gen(1)
            p2 = x**6 + R(4)*x**4*y**2 + R(2)*x**3*y**3 + R(3)*x**2*y**4 + \
            x*y**5 + R(7)*x**2 + R(5)*x*y + R(3)*y**2 + R(2)*x + y + R(10)
            sphinx_plot(p2.tropical_variety().plot())
        """
        from sage.plot.plot import plot
        from sage.plot.text import text
        from sage.plot.graphics import Graphics
        from sage.plot.plot import parametric_plot

        if not self._hypersurface:
            return plot(lambda x: float('nan'), {-1, 1})

        combined_plot = Graphics()
        large_int = 100
        intervals = self._parameter_intervals()
        for i, component in enumerate(self._hypersurface):
            var = component[1][0].variables()[0]
            parametric_function = component[0]
            order = component[2]
            interval = intervals[i]
            if interval[0].lower() == -infinity:
                lower = interval[0].upper() - large_int
                upper = interval[0].upper()
                midpoint = upper - 0.5
            elif interval[0].upper() == infinity:
                lower = interval[0].lower()
                upper = interval[0].lower() + large_int
                midpoint = lower + 0.5
            else:
                lower = interval[0].lower()
                upper = interval[0].upper()
                midpoint = (lower+upper) / 2

            if (lower == infinity) and (upper == infinity):
                midpoint = 0
                plot = parametric_plot(parametric_function, (var, -large_int,
                                       large_int), color='red')
            else:
                plot = parametric_plot(parametric_function, (var, lower, upper),
                                       color='red')

            # Add the order if it is greater than or equal to 2
            if component[2] > 1:
                point = []
                for eq in component[0]:
                    value = eq.subs(**{str(var): midpoint})
                    point.append(value)
                text_order = text(str(order), (point[0], point[1]),
                                  fontsize=16, color='black')
                combined_plot += plot + text_order
            else:
                combined_plot += plot

        # Set default axes
        axes = self._axes()
        xmin, xmax = axes[0][0], axes[0][1]
        ymin, ymax = axes[1][0], axes[1][1]
        combined_plot.set_axes_range(xmin=xmin, xmax=xmax,
                                     ymin=ymin, ymax=ymax)
        return combined_plot

    def _repr_(self):
        """
        Return a string representation of ``self``.

        EXAMPLES::

            sage: T = TropicalSemiring(QQ)
            sage: R.<x,y> = PolynomialRing(T)
            sage: (x^2+R(0)).tropical_variety()
            Tropical curve of 0*x^2 + 0
        """
        return f"Tropical curve of {self._poly}"