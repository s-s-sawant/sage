r"""
Classes for symbolic functions

.. _symbolic-function-classes:

To enable their usage as part of symbolic expressions, symbolic function
classes are derived from one of the subclasses of :class:`Function`:

 * :class:`BuiltinFunction`: the code of these functions is written in Python;
   many :ref:`special functions<special-functions>` are of this type
 * :class:`GinacFunction`: the code of these functions is written in C++ and
   part of the Pynac support library; most elementary functions are of this type
 * :class:`SymbolicFunction`: symbolic functions defined on the Sage command
   line are of this type

Sage uses ``BuiltinFunction`` and ``GinacFunction`` for its symbolic builtin
functions. Users can define any other additional ``SymbolicFunction`` through
the ``function()`` factory, see :doc:`function_factory`

Several parameters are supported by the superclass' ``__init__()`` method.
Examples follow below.

 * ``nargs``: the number of arguments
 * ``name``: the string that is printed on the CLI; the name of the member
   functions that are attempted for evaluation of Sage element arguments; also
   the name of the Pynac function that is associated with a ``GinacFunction``
 * ``alt_name``: the second name of the member functions that are attempted for
   evaluation of Sage element arguments
 * ``latex_name``: what is printed when ``latex(f(...))`` is called
 * ``conversions``: a dict containing the function's name in other CAS
 * ``evalf_params_first``: if ``False``, when floating-point evaluating the
   expression do not evaluate function arguments before calling the
   ``_evalf_()`` member of the function
 * ``preserved_arg``: if nonzero, the index (starting with ``1``) of the
   function argument that determines the return type. Note that, e.g,
   ``atan2()`` uses both arguments to determine return type, through a
   different mechanism

Function classes can define the following Python member functions:

 * ``_eval_(*args)``: the only mandatory member function, evaluating the
   argument and returning the result; if ``None`` is returned the expression
   stays unevaluated
 * ``_eval_numpy_(*args)``: evaluation of ``f(args)`` with arguments of numpy
   type
 * ``_evalf_(*args, **kwds)``: called when the expression is floating-point
   evaluated; may receive a ``parent`` keyword specifying the expected parent
   of the result. If not defined an attempt is made to convert the result of
   ``_eval_()``.
 * ``_conjugate_(*args)``, ``_real_part_(*args)``, ``_imag_part_(*args)``:
   return conjugate, real part, imaginary part of the expression ``f(args)``
 * ``_derivative_(*args, index)``: return derivative with respect to the
   parameter indexed by ``index`` (starting with 0) of ``f(args)``
 * ``_tderivative_()``: same as ``_derivative_()`` but don't apply chain rule;
   only one of the two functions may be defined
 * ``_power_(*args, expo)``: return ``f(args)^expo``
 * ``_series_(*args, **kwds)``: return the power series at ``at`` up to
   ``order`` with respect to ``var`` of ``f(args)``; these three values are
   received in ``kwds``. If not defined the series is attempted to be computed
   by differentiation.
 * ``print(*args)``: return what should be printed on the CLI with ``f(args)``
 * ``print_latex(*args)``: return what should be output with ``latex(f(args))``

The following examples are intended for Sage developers. Users can define
functions interactively through the ``function()`` factory, see
:doc:`function_factory`.

EXAMPLES:

The simplest example is a function returning nothing, it practically behaves
like a symbol. Setting ``nargs=0`` allows any number of arguments::

    sage: from sage.symbolic.function import BuiltinFunction
    sage: class Test1(BuiltinFunction):
    ....:     def __init__(self):
    ....:         BuiltinFunction.__init__(self, 'test', nargs=0)
    ....:     def _eval_(self, *args):
    ....:         pass
    sage: f = Test1()
    sage: f()
    test()
    sage: f(1,2,3)*f(1,2,3)
    test(1, 2, 3)^2

In the following the ``sin`` function of ``CBF(0)`` is called because with
floating point arguments the ``CBF`` element's ``my_sin()`` member function
is attempted, and after that ``sin()`` which succeeds::

    sage: class Test2(BuiltinFunction):
    ....:     def __init__(self):
    ....:         BuiltinFunction.__init__(self, 'my_sin', alt_name='sin',
    ....:                                  latex_name=r'\SIN', nargs=1)
    ....:     def _eval_(self, x):
    ....:         return 5
    ....:     def _evalf_(self, x, **kwds):
    ....:         return 3.5
    sage: f = Test2()
    sage: f(0)
    5
    sage: f(0, hold=True)
    my_sin(0)
    sage: f(0, hold=True).n()
    3.50000000000000
    sage: f(CBF(0))
    0

    sage: latex(f(0, hold=True))
    \SIN\left(0\right)
    sage: f(1,2)
    Traceback (most recent call last):
    ...
    TypeError: Symbolic function my_sin takes exactly 1 arguments (2 given)

"""

#*****************************************************************************
#       Copyright (C) 2008 - 2010 Burcin Erocal <burcin@erocal.org>
#       Copyright (C) 2008 William Stein <wstein@gmail.com>
#       Copyright (C) 2016 Vincent Delecroix <vincent.delecroix@u-bordeaux.fr>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************

from sage.symbolic.pynac cimport *
from sage.rings.integer cimport smallInteger
from sage.structure.sage_object cimport SageObject
from sage.structure.element cimport Element, parent
from sage.misc.lazy_attribute import lazy_attribute
from .expression cimport new_Expression_from_GEx, Expression
from .ring import SR

from sage.structure.coerce cimport (coercion_model,
        py_scalar_to_element, is_numpy_type, is_mpmath_type)
from sage.structure.richcmp cimport richcmp

# we keep a database of symbolic functions initialized in a session
# this also makes the .operator() method of symbolic expressions work
cdef dict sfunction_serial_dict = {}

from sage.misc.fpickle import pickle_function, unpickle_function
from sage.cpython.string cimport str_to_bytes
from sage.ext.fast_eval import FastDoubleFunc

# List of functions which ginac allows us to define custom behavior for.
# Changing the order of this list could cause problems unpickling old pickles.
sfunctions_funcs = ['eval', 'evalf', 'conjugate', 'real_part', 'imag_part',
        'derivative', 'power', 'series', 'print', 'print_latex', 'tderivative']

cdef class Function(SageObject):
    """
    Base class for symbolic functions defined through Pynac in Sage.

    This is an abstract base class, with generic code for the interfaces
    and a :meth:`__call__` method. Subclasses should implement the
    :meth:`_is_registered` and :meth:`_register_function` methods.

    This class is not intended for direct use, instead use one of the
    subclasses :class:`BuiltinFunction` or :class:`SymbolicFunction`.
    """
    def __init__(self, name, nargs, latex_name=None, conversions=None,
            evalf_params_first=True, alt_name=None):
        """
        This is an abstract base class. It's not possible to test it directly.

        EXAMPLES::

            sage: f = function('f', nargs=1, conjugate_func=lambda self,x: 2r*x) # indirect doctest
            sage: f(2)
            f(2)
            sage: f(2).conjugate()
            4

        TESTS::

            # eval_func raises exception
            sage: def ef(self, x): raise RuntimeError("foo")
            sage: bar = function("bar", nargs=1, eval_func=ef)
            sage: bar(x)
            Traceback (most recent call last):
            ...
            RuntimeError: foo

            # eval_func returns non coercible
            sage: def ef(self, x): return ZZ
            sage: bar = function("bar", nargs=1, eval_func=ef)
            sage: bar(x)
            Traceback (most recent call last):
            ...
            TypeError: function did not return a symbolic expression or an element that can be coerced into a symbolic expression

            # eval_func is not callable
            sage: bar = function("bar", nargs=1, eval_func=5)
            Traceback (most recent call last):
            ...
            ValueError: eval_func parameter must be callable
        """
        self._name = name
        self._alt_name = alt_name
        self._nargs = nargs
        self._latex_name = latex_name
        self._evalf_params_first = evalf_params_first
        self._conversions = {} if conversions is None else conversions

        # handle custom printing
        # if print_func is defined, it is used instead of name
        # latex printing can be customised either by setting a string latex_name
        # or giving a custom function argument print_latex_func
        if latex_name and hasattr(self, '_print_latex_'):
            raise ValueError("only one of latex_name or _print_latex_ should be specified.")

        # only one of derivative and tderivative should be defined
        if hasattr(self, '_derivative_') and hasattr(self, '_tderivative_'):
            raise ValueError("only one of _derivative_ or _tderivative_ should be defined.")

        for fname in sfunctions_funcs:
            real_fname = '_%s_'%fname
            if hasattr(self, real_fname) and not \
                    callable(getattr(self, real_fname)):
                raise ValueError(real_fname + " parameter must be callable")

        if not self._is_registered():
            self._register_function()

            global sfunction_serial_dict
            sfunction_serial_dict[self._serial] = self

            from sage.symbolic.pynac import symbol_table, register_symbol
            symbol_table['functions'][self._name] = self

            register_symbol(self, self._conversions)

    cdef _is_registered(self):
        """
        Check if this function is already registered. If it is, set
        `self._serial` to the right value.
        """
        raise NotImplementedError("this is an abstract base class, it shouldn't be initialized directly")

    cdef _register_function(self):
        """

        TESTS:

        After :trac:`9240`, pickling and unpickling of symbolic
        functions was broken. We check here that this is fixed
        (:trac:`11919`)::

            sage: f = function('f')(x)
            sage: s = dumps(f)
            sage: loads(s)
            f(x)
            sage: deepcopy(f)
            f(x)

        """
        cdef GFunctionOpt opt
        opt = g_function_options_args(str_to_bytes(self._name), self._nargs)

        if hasattr(self, '_eval_'):
            opt.eval_func(self)

        if not self._evalf_params_first:
            opt.do_not_evalf_params()

        if hasattr(self, '_subs_'):
            opt.subs_func(self)

        if hasattr(self, '_evalf_'):
            opt.evalf_func(self)

        if hasattr(self, '_conjugate_'):
            opt.conjugate_func(self)

        if hasattr(self, '_real_part_'):
            opt.real_part_func(self)

        if hasattr(self, '_imag_part_'):
            opt.imag_part_func(self)

        if hasattr(self, '_derivative_'):
            opt.derivative_func(self)

        if hasattr(self, '_tderivative_'):
            opt.do_not_apply_chain_rule()
            opt.derivative_func(self)

        if hasattr(self, '_power_'):
            opt.power_func(self)

        if hasattr(self, '_series_'):
            opt.series_func(self)

        # custom print functions are called from python
        # so we don't register them with the ginac function_options object

        if self._latex_name:
            opt.latex_name(str_to_bytes(self._latex_name))

        self._serial = g_register_new(opt)
        g_foptions_assign(g_registered_functions().index(self._serial), opt)

    def _evalf_try_(self, *args):
        """
        Call :meth:`_evalf_` if one the arguments is numerical and none
        of the arguments are symbolic.

        OUTPUT:

        - ``None`` if we didn't succeed to call :meth:`_evalf_` or if
          the input wasn't suitable for it.

        - otherwise, a numerical value for the function.

        TESTS::

            sage: coth(5)  # indirect doctest
            coth(5)
            sage: coth(0.5)
            2.16395341373865
            sage: from sage.symbolic.function import BuiltinFunction
            sage: class Test(BuiltinFunction):
            ....:     def __init__(self):
            ....:         BuiltinFunction.__init__(self, 'test', nargs=2)
            ....:     def _evalf_(self, x, y, parent):
            ....:         return x + 1
            ....:     def _eval_(self, x, y):
            ....:         res = self._evalf_try_(x, y)
            ....:         if res:
            ....:             return res
            ....:         elif x == 2:
            ....:             return 3
            ....:         else:
            ....:             return
            sage: test = Test()
            sage: test(1.3, 4)
            2.30000000000000
            sage: test(pi, 4)
            test(pi, 4)
            sage: test(2, x)
            3
            sage: test(2., 4)
            3.00000000000000
            sage: test(1 + 1.0*I, 2)
            2.00000000000000 + 1.00000000000000*I
            sage: class Test2(BuiltinFunction):
            ....:     def __init__(self):
            ....:         BuiltinFunction.__init__(self, 'test', nargs=1)
            ....:     def _evalf_(self, x, parent):
            ....:         return 0.5
            ....:     def _eval_(self, x):
            ....:         res = self._evalf_try_(x)
            ....:         if res:
            ....:             return res
            ....:         else:
            ....:             return 3
            sage: test2 = Test2()
            sage: test2(1.3)
            0.500000000000000
            sage: test2(pi)
            3
        """
        # If any of the inputs is numerical and none is symbolic,
        # try to call _evalf_() directly
        try:
            evalf = self._evalf_  # catch AttributeError early
            if any(self._is_numerical(x) for x in args):
                if not any(isinstance(x, Expression) for x in args):
                    p = coercion_model.common_parent(*args)
                    return evalf(*args, parent=p)
        except Exception:
            pass

    def __hash__(self):
        """
        EXAMPLES::

            sage: f = function('f', nargs=1, conjugate_func=lambda self,x: 2r*x)
            sage: f.__hash__() #random
            -2224334885124003860
            sage: hash(f(2)) #random
            4168614485
        """
        return hash(self._name)*(self._nargs+1)*self._serial

    def __repr__(self):
        """
        EXAMPLES::

            sage: foo = function("foo", nargs=2); foo
            foo
        """
        return self._name

    def _latex_(self):
        r"""
        EXAMPLES::

            sage: from sage.symbolic.function import SymbolicFunction
            sage: s = SymbolicFunction('foo'); s
            foo
            sage: latex(s)
            foo
            sage: s = SymbolicFunction('foo', latex_name=r'{\rm foo}')
            sage: latex(s)
            {\rm foo}
            sage: s._latex_()
            '{\\rm foo}'
        """
        if self._latex_name is not None:
            return self._latex_name
        else:
            return self._name

    def __richcmp__(self, other, op):
        """
        TESTS::

            sage: foo = function("foo", nargs=2)
            sage: foo == foo
            True
            sage: foo == 2
            False
            sage: foo(1,2).operator() == foo
            True

        """
        try:
            return richcmp((<Function>self)._serial,
                           (<Function>other)._serial, op)
        except AttributeError:
            return NotImplemented

    def __call__(self, *args, bint coerce=True, bint hold=False):
        """
        Evaluates this function at the given arguments.

        We coerce the arguments into symbolic expressions if coerce=True, then
        call the Pynac evaluation method, which in turn passes the arguments to
        a custom automatic evaluation method if ``_eval_()`` is defined.

        EXAMPLES::

            sage: foo = function("foo", nargs=2)
            sage: x,y,z = var("x y z")
            sage: foo(x,y)
            foo(x, y)

            sage: foo(y)
            Traceback (most recent call last):
            ...
            TypeError: Symbolic function foo takes exactly 2 arguments (1 given)

            sage: bar = function("bar")
            sage: bar(x)
            bar(x)
            sage: bar(x,y)
            bar(x, y)

        The `hold` argument prevents automatic evaluation of the function::

            sage: exp(log(x))
            x
            sage: exp(log(x), hold=True)
            e^log(x)

        We can also handle numpy types::

            sage: import numpy
            sage: sin(numpy.arange(5))
            array([ 0.        ,  0.84147098,  0.90929743,  0.14112001, -0.7568025 ])

        Symbolic functions evaluate non-exact input numerically, and return
        symbolic expressions on exact input, or if any input is symbolic::

            sage: arctan(1)
            1/4*pi
            sage: arctan(float(1))
            0.7853981633974483
            sage: type(lambert_w(SR(0)))
            <type 'sage.symbolic.expression.Expression'>

        Precision of the result depends on the precision of the input::

            sage: arctan(RR(1))
            0.785398163397448
            sage: arctan(RealField(100)(1))
            0.78539816339744830961566084582

        Return types for non-exact input depends on the input type::

            sage: type(exp(float(0)))
            <... 'float'>
            sage: exp(RR(0)).parent()
            Real Field with 53 bits of precision


        TESTS:

        Test coercion::

            sage: bar(ZZ)
            Traceback (most recent call last):
            ...
            TypeError: cannot coerce arguments: ...
            sage: exp(QQbar(I))
            e^I

        For functions with single argument, if coercion fails we try to call
        a method with the name of the function on the object::

            sage: M = matrix(SR, 2, 2, [x, 0, 0, I*pi])
            sage: exp(M)
            [e^x   0]
            [  0  -1]

        Make sure we can pass mpmath arguments (:trac:`13608`)::

            sage: import mpmath
            sage: with mpmath.workprec(128): sin(mpmath.mpc('0.5', '1.2'))
            mpc(real='0.86807452059118713192871150787046523179886', imag='1.3246769633571289324095313649562791720086')

        Check that :trac:`10133` is fixed::

            sage: out = sin(0)
            sage: out, parent(out)
            (0, Integer Ring)
            sage: out = sin(int(0))
            sage: (out, parent(out))
            (0, <... 'int'>)
            sage: out = arctan2(int(0), float(1))
            sage: (out, parent(out))
            (0, <... 'int'>)
            sage: out = arctan2(int(0), RR(1))
            sage: (out, parent(out))
            (0, Integer Ring)

        Check that `real_part` and `imag_part` still works after :trac:`21216`::

            sage: import numpy
            sage: a = numpy.array([1+2*I, -2-3*I], dtype=complex)
            sage: real_part(a)
            array([ 1., -2.])
            sage: imag_part(a)
            array([ 2., -3.])
        """
        if self._nargs > 0 and len(args) != self._nargs:
            raise TypeError("Symbolic function %s takes exactly %s arguments (%s given)" % (self._name, self._nargs, len(args)))

        # support fast_float
        if self._nargs == 1:
            if isinstance(args[0], FastDoubleFunc):
                try:
                    method = getattr(args[0], self._name)
                except AttributeError:
                    raise TypeError("cannot handle fast float arguments")
                else:
                    return method()

        # if the given input is a symbolic expression, we don't convert it back
        # to a numeric type at the end
        if any(parent(arg) is SR for arg in args):
            symbolic_input = True
        else:
            symbolic_input = False

        cdef Py_ssize_t i
        if coerce:
            try:
                args = [SR.coerce(a) for a in args]
            except TypeError as err:
                # If the function takes only one argument, we try to call
                # a method with the name of this function on the object.
                # This makes the following work:
                #     sage: M = matrix(SR, 2, 2, [x, 0, 0, I*pi])
                #     sage: exp(M)
                #     [e^x   0]
                #     [  0  -1]
                if len(args) == 1:
                    method = getattr(args[0], self._name, None)
                    if callable(method):
                        return method()
                raise TypeError("cannot coerce arguments: %s" % (err))

        else: # coerce == False
            for a in args:
                if not isinstance(a, Expression):
                    raise TypeError("arguments must be symbolic expressions")

        cdef GEx res
        cdef GExVector vec
        if self._nargs == 0 or self._nargs > 3:
            for i from 0 <= i < len(args):
                vec.push_back((<Expression>args[i])._gobj)
            res = g_function_evalv(self._serial, vec, hold)
        elif self._nargs == 1:
            res = g_function_eval1(self._serial,
                    (<Expression>args[0])._gobj, hold)
        elif self._nargs == 2:
            res = g_function_eval2(self._serial, (<Expression>args[0])._gobj,
                    (<Expression>args[1])._gobj, hold)
        elif self._nargs == 3:
            res = g_function_eval3(self._serial,
                    (<Expression>args[0])._gobj, (<Expression>args[1])._gobj,
                    (<Expression>args[2])._gobj, hold)

        if not symbolic_input and is_a_numeric(res):
            return py_object_from_numeric(res)

        return new_Expression_from_GEx(SR, res)

    def name(self):
        """
        Return the name of this function.

        EXAMPLES::

            sage: foo = function("foo", nargs=2)
            sage: foo.name()
            'foo'
        """
        return self._name

    def number_of_arguments(self):
        """
        Return the number of arguments that this function takes.

        EXAMPLES::

            sage: foo = function("foo", nargs=2)
            sage: foo.number_of_arguments()
            2
            sage: foo(x,x)
            foo(x, x)

            sage: foo(x)
            Traceback (most recent call last):
            ...
            TypeError: Symbolic function foo takes exactly 2 arguments (1 given)
        """
        return self._nargs

    def variables(self):
        """
        Return the variables (of which there are none) present in this function.

        EXAMPLES::

            sage: sin.variables()
            ()
        """
        return ()

    def default_variable(self):
        """
        Return a default variable.

        EXAMPLES::

            sage: sin.default_variable()
            x
        """
        return SR.var('x')

    def _is_numerical(self, x):
        """
        Return True if `x` is a numerical object.

        This is used to determine whether to call the :meth:`_evalf_`
        method instead of the :meth:`_eval_` method.

        This is a non-static method since whether or not an argument is
        considered numerical may depend on the specific function.

        TESTS::

            sage: [sin._is_numerical(a) for a in [5., 5.4r]]
            [True, True]
            sage: [sin._is_numerical(a) for a in [5, pi]]
            [False, False]
            sage: [sin._is_numerical(R(1)) for R in [RIF, CIF, RBF, CBF]]
            [False, False, False, False]

        The following calls used to yield incorrect results because intervals
        were considered numerical by this method::

            sage: b = RBF(3/2, 1e-10)
            sage: airy_ai(b)
            airy_ai([1.500000000 +/- 1.01e-10])
            sage: gamma(b, 1)
            gamma([1.500000000 +/- 1.01e-10], 1)
            sage: hurwitz_zeta(b, b)
            hurwitz_zeta([1.500000000 +/- 1.01e-10], [1.500000000 +/- 1.01e-10])
            sage: hurwitz_zeta(1/2, b)
            hurwitz_zeta(1/2, [1.500000000 +/- 1.01e-10])

            sage: iv = RIF(1, 1.0001)
            sage: airy_ai(iv)
            airy_ai(1.0001?)
            sage: airy_ai(CIF(iv))
            airy_ai(1.0001?)
        """
        if isinstance(x, (float, complex)):
            return True
        if isinstance(x, Element):
            parent = (<Element>x)._parent
            return hasattr(parent, 'precision') and parent._is_numerical()
        return False

    def _interface_init_(self, I=None):
        """
        EXAMPLES::

             sage: sin._interface_init_(maxima)
             'sin'
        """
        if I is None:
            return self._name
        return self._conversions.get(I.name(), self._name)

    def _mathematica_init_(self):
        """
        EXAMPLES::

             sage: sin._mathematica_init_()
             'Sin'
             sage: exp._mathematica_init_()
             'Exp'
             sage: (exp(x) + sin(x) + tan(x))._mathematica_init_()
             '(Exp[x])+(Sin[x])+(Tan[x])'
        """
        s = self._conversions.get('mathematica', None)
        return s if s is not None else repr(self).capitalize()

    def _sympy_init_(self, I=None):
        """
        EXAMPLES::

            sage: arcsin._sympy_init_()
            'asin'
            sage: from sage.symbolic.function import SymbolicFunction
            sage: g = SymbolicFunction('g', conversions=dict(sympy='gg'))
            sage: g._sympy_init_()
            'gg'
            sage: g(x)._sympy_()
            gg(x)
        """
        return self._conversions.get('sympy', self._name)

    @lazy_attribute
    def _sympy_(self):
        """
        EXAMPLES::

            sage: cos._sympy_()
            cos
            sage: _(0)
            1
        """
        f = self._sympy_init_()
        import sympy
        if getattr(sympy, f, None):
            def return_sympy():
                return getattr(sympy, f)
            return return_sympy
        return NotImplemented

    def _maxima_init_(self, I=None):
        """
        EXAMPLES::

            sage: exp._maxima_init_()
            'exp'
            sage: from sage.symbolic.function import SymbolicFunction
            sage: f = SymbolicFunction('f', latex_name='f', conversions=dict(maxima='ff'))
            sage: f._maxima_init_()
            'ff'
        """
        return self._conversions.get('maxima', self._name)

    def _fast_float_(self, *vars):
        """
        Returns an object which provides fast floating point evaluation of
        self.

        See sage.ext.fast_eval? for more information.

        EXAMPLES::

            sage: sin._fast_float_()
            <sage.ext.fast_eval.FastDoubleFunc object at 0x...>
            sage: sin._fast_float_()(0)
            0.0

        ::

            sage: ff = cos._fast_float_(); ff
            <sage.ext.fast_eval.FastDoubleFunc object at 0x...>
            sage: ff.is_pure_c()
            True
            sage: ff(0)
            1.0

        ::

            sage: ff = erf._fast_float_()
            sage: ff.is_pure_c()
            False
            sage: ff(1.5) # tol 1e-15
            0.9661051464753108
            sage: erf(1.5)
            0.966105146475311
        """
        import sage.ext.fast_eval as fast_float

        args = [fast_float.fast_float_arg(n) for n in range(self.number_of_arguments())]
        try:
            return self(*args)
        except TypeError as err:
            return fast_float.fast_float_func(self, *args)

    def _fast_callable_(self, etb):
        r"""
        Given an ExpressionTreeBuilder, return an Expression representing
        this value.

        EXAMPLES::

            sage: from sage.ext.fast_callable import ExpressionTreeBuilder
            sage: etb = ExpressionTreeBuilder(vars=['x','y'])
            sage: sin._fast_callable_(etb)
            sin(v_0)
            sage: erf._fast_callable_(etb)
            {erf}(v_0)
        """
        args = [etb._var_number(n) for n in range(self.number_of_arguments())]
        return etb.call(self, *args)

    def _eval_numpy_(self, *args):
        r"""
        Evaluates this function at the given arguments.

        At least one of elements of args is supposed to be a numpy array.

        EXAMPLES::

            sage: import numpy
            sage: a = numpy.arange(5)
            sage: csc(a)
            doctest:...: RuntimeWarning: divide by zero encountered in ...divide
            array([        inf,  1.18839511,  1.09975017,  7.0861674 , -1.32134871])

            sage: factorial(a)
            Traceback (most recent call last):
            ...
            NotImplementedError: The Function factorial does not support numpy arrays as arguments
        """
        raise NotImplementedError("The Function %s does not support numpy arrays as arguments" % self.name())

    def _eval_mpmath_(self, *args):
        r"""
        Evaluates this function for arguments of mpmath types.

        This is only called when no such mpmath function exists. It casts its
        arguments to sage reals of the appropriate precision.

        EXAMPLES:

        At the time of this writing, mpmath had no arcsin, only asin.
        So the following call would actually fall back to the default
        implementation, using sage reals instead of mpmath ones. This
        might change when aliases for these functions are established::

            sage: import mpmath
            sage: with mpmath.workprec(128): arcsin(mpmath.mpf('0.5'))
            mpf('0.52359877559829887307710723054658381403157')

        TESTS:

        To ensure that we actually can fall back to an implementation
        not using mpmath, we have to create a custom function which
        will certainly never get created in mpmath. ::

            sage: import mpmath
            sage: from sage.symbolic.function import BuiltinFunction
            sage: class NoMpmathFn(BuiltinFunction):
            ....:         def _eval_(self, arg):
            ....:                 parent = arg.parent()
            ....:                 prec = parent.prec()
            ....:                 assert parent == RealField(prec)
            ....:                 return prec
            sage: noMpmathFn = NoMpmathFn("noMpmathFn")
            sage: with mpmath.workprec(64): noMpmathFn(sqrt(mpmath.mpf('2')))
            64
            sage: mpmath.noMpmathFn = lambda x: 123
            sage: with mpmath.workprec(64): noMpmathFn(sqrt(mpmath.mpf('2')))
            123
            sage: del mpmath.noMpmathFn

        """
        import mpmath
        from sage.libs.mpmath.utils import mpmath_to_sage, sage_to_mpmath
        prec = mpmath.mp.prec
        args = [mpmath_to_sage(x, prec)
                if isinstance(x, (mpmath.mpf, mpmath.mpc)) else x
                for x in args]
        res = self(*args)
        res = sage_to_mpmath(res, prec)
        return res

cdef class GinacFunction(BuiltinFunction):
    """
    This class provides a wrapper around symbolic functions already defined in
    Pynac/GiNaC.

    GiNaC provides custom methods for these functions defined at the C++ level.
    It is still possible to define new custom functionality or override those
    already defined.

    There is also no need to register these functions.
    """
    def __init__(self, name, nargs=1, latex_name=None, conversions=None,
            ginac_name=None, evalf_params_first=True, preserved_arg=None,
            alt_name=None):
        """
        TESTS::

            sage: from sage.functions.trig import Function_sin
            sage: s = Function_sin() # indirect doctest
            sage: s(0)
            0
            sage: s(pi)
            0
            sage: s(pi/2)
            1
        """
        self._ginac_name = ginac_name
        BuiltinFunction.__init__(self, name, nargs, latex_name, conversions,
                evalf_params_first=evalf_params_first,
                preserved_arg=preserved_arg, alt_name=alt_name)

    cdef _is_registered(self):
        # Since this is function is defined in C++, it is already in
        # ginac's function registry
        fname = self._ginac_name if self._ginac_name is not None else self._name
        # get serial
        try:
            self._serial = find_function(str_to_bytes(fname), self._nargs)
        except RuntimeError as err:
            raise ValueError("cannot find GiNaC function with name %s and %s arguments" % (fname, self._nargs))

        global sfunction_serial_dict
        return self._serial in sfunction_serial_dict

    cdef _register_function(self):
        # We don't need to add anything to GiNaC's function registry
        # However, if any custom methods were provided in the python class,
        # we should set the properties of the function_options object
        # corresponding to this function
        cdef GFunctionOpt opt = g_registered_functions().index(self._serial)

        if hasattr(self, '_eval_'):
            opt.eval_func(self)

        if not self._evalf_params_first:
            opt.do_not_evalf_params()

        if hasattr(self, '_evalf_'):
            opt.evalf_func(self)

        if hasattr(self, '_conjugate_'):
            opt.conjugate_func(self)

        if hasattr(self, '_real_part_'):
            opt.real_part_func(self)

        if hasattr(self, '_imag_part_'):
            opt.imag_part_func(self)

        if hasattr(self, '_derivative_'):
            opt.derivative_func(self)

        if hasattr(self, '_tderivative_'):
            opt.do_not_apply_chain_rule()
            opt.derivative_func(self)

        if hasattr(self, '_power_'):
            opt.power_func(self)

        if hasattr(self, '_series_'):
            opt.series_func(self)

        # overriding print functions is not supported

        if self._latex_name:
            opt.latex_name(str_to_bytes(self._latex_name))

        g_foptions_assign(g_registered_functions().index(self._serial), opt)


cdef class BuiltinFunction(Function):
    """
    This is the base class for symbolic functions defined in Sage.

    If a function is provided by the Sage library, we don't need to pickle
    the custom methods, since we can just initialize the same library function
    again. This allows us to use Cython for custom methods.

    We assume that each subclass of this class will define one symbolic
    function. Make sure you use subclasses and not just call the initializer
    of this class.
    """
    def __init__(self, name, nargs=1, latex_name=None, conversions=None,
            evalf_params_first=True, alt_name=None, preserved_arg=None):
        """
        TESTS::

            sage: from sage.functions.trig import Function_cot
            sage: c = Function_cot() # indirect doctest
            sage: c(pi/2)
            0
        """
        self._preserved_arg = preserved_arg
        if preserved_arg and (preserved_arg < 1 or preserved_arg > nargs):
            raise ValueError("preserved_arg must be between 1 and nargs")

        # If we have an _evalf_ method, change _eval_ to a
        # wrapper function which first tries to call _evalf_.
        if hasattr(self, '_evalf_'):
            if hasattr(self, '_eval_'):
                self._eval0_ = self._eval_
                self._eval_ = self._evalf_or_eval_
            else:
                self._eval_ = self._evalf_try_
        Function.__init__(self, name, nargs, latex_name, conversions,
                evalf_params_first, alt_name = alt_name)

    def _method_arguments(self, arg):
        r"""
        Rewrite the arguments before calling a specialized implementation.

        Rewrite the list of arguments of this symbolic function in a form
        suitable for calling dedicated implementations that come as methods of
        a “main” argument.

        The default implementation of this method handles the case of
        univariate functions. Multivariate symbolic functions should override
        it as appropriate.

        EXAMPLES::

            sage: zeta._method_arguments(1)
            [1]
            sage: zetaderiv._method_arguments(2, 3)
            [3, 2]
            sage: zeta._method_arguments(2, 3)
            Traceback (most recent call last):
            ...
            TypeError: ...
        """
        return [arg]

    def __call__(self, *args, bint coerce=True, bint hold=False,
            bint dont_call_method_on_arg=False):
        r"""
        Evaluate this function on the given arguments and return the result.

        EXAMPLES::

            sage: exp(5)
            e^5
            sage: gamma(15)
            87178291200

        Python float, Python complex, mpmath mpf and mpc as well as numpy inputs
        are sent to the relevant ``math``, ``cmath``, ``mpmath`` or ``numpy``
        function::

            sage: cos(1.r)
            0.5403023058681398
            sage: assert type(_) is float
            sage: gamma(4.r)
            6.0
            sage: assert type(_) is float

            sage: cos(1jr)  # abstol 1e-15
            (1.5430806348152437-0j)
            sage: assert type(_) is complex

            sage: import mpmath
            sage: cos(mpmath.mpf('1.321412'))
            mpf('0.24680737898640387')
            sage: cos(mpmath.mpc(1,1))
            mpc(real='0.83373002513114902', imag='-0.98889770576286506')

            sage: import numpy
            sage: sin(numpy.int32(0))
            0.0
            sage: type(_)
            <type 'numpy.float64'>

        TESTS::

            sage: from sage.symbolic.function import BuiltinFunction
            sage: class A:
            ....:     def foo(self):
            ....:         return 'foo'
            sage: foo = BuiltinFunction(name='foo')
            sage: foo(A())
            'foo'
            sage: bar = BuiltinFunction(name='bar', alt_name='foo')
            sage: bar(A())
            'foo'
        """
        res = None
        if args and not hold:
            # try calling the relevant math, cmath, mpmath or numpy function.
            # And as a fallback try the custom self._eval_numpy_ or
            # self._eval_mpmath_
            module = None
            custom = None
            if any(is_numpy_type(type(arg)) for arg in args):
                import numpy as module
                custom = self._eval_numpy_
            elif any(is_mpmath_type(type(arg)) for arg in args):
                import mpmath as module
                custom = self._eval_mpmath_
            elif all(isinstance(arg, float) for arg in args):
                # We do not include the factorial here as
                # factorial(integer-valued float) is deprecated in Python 3.9.
                # This special case should be removed when
                # Python always raise an error for factorial(float).
                # This case will be delegated to the gamma function.
                # see Trac ticket #30764
                if self._name != 'factorial':
                    import math as module
            elif all(isinstance(arg, complex) for arg in args):
                import cmath as module

            if module is not None:
                func = getattr(module, self._name, None)
                if func is None and self._alt_name is not None:
                    func = getattr(module, self._alt_name, None)

                if callable(func):
                    try:
                        return func(*args)
                    except (ValueError, TypeError):
                        pass

            if custom is not None:
                return custom(*args)

        if not hold and not dont_call_method_on_arg:
            try:
                method_args = self._method_arguments(*args)
            except TypeError:
                pass
            else:
                # then try to see whether there exists a method on the object
                # with the given name
                arg = py_scalar_to_element(method_args[0])
                method = getattr(arg, self._name, None)
                if method is None and self._alt_name is not None:
                    method = getattr(arg, self._alt_name, None)

                if callable(method):
                    try:
                        res = method(*method_args[1:])
                    except (TypeError, ValueError, ArithmeticError):
                        pass

        if res is None:
            res = self._evalf_try_(*args)
            if res is None:
                res = super(BuiltinFunction, self).__call__(
                        *args, coerce=coerce, hold=hold)

        # Convert the output back to the corresponding
        # Python type if possible.
        if any(isinstance(x, Element) for x in args):
            if (self._preserved_arg
                    and isinstance(args[self._preserved_arg-1], Element)):
                arg_parent = parent(args[self._preserved_arg-1])
                if arg_parent is SR:
                    return res
                from sage.rings.polynomial.polynomial_ring import PolynomialRing_commutative
                from sage.rings.polynomial.multi_polynomial_ring import MPolynomialRing_polydict_domain
                if (isinstance(arg_parent, PolynomialRing_commutative)
                    or isinstance(arg_parent, MPolynomialRing_polydict_domain)):
                    try:
                        return SR(res).polynomial(ring=arg_parent)
                    except TypeError:
                        return res
                else:
                    try:
                        return arg_parent(res)
                    except TypeError:
                        return res
            return res
        if not isinstance(res, Element):
            return res

        p = res.parent()
        from sage.rings.all import ZZ, RDF, CDF
        if ZZ.has_coerce_map_from(p):
            return int(res)
        elif RDF.has_coerce_map_from(p):
            return float(res)
        elif CDF.has_coerce_map_from(p):
            return complex(res)
        else:
            return res

    cdef _is_registered(self):
        """
        TESTS:

        Check if :trac:`13586` is fixed::

            sage: from sage.symbolic.function import BuiltinFunction
            sage: class AFunction(BuiltinFunction):
            ....:       def __init__(self, name, exp=1):
            ....:           self.exponent=exp
            ....:           BuiltinFunction.__init__(self, name, nargs=1)
            ....:       def _eval_(self, arg):
            ....:               return arg**self.exponent
            sage: p2 = AFunction('p2', 2)
            sage: p2(x)
            x^2
            sage: p3 = AFunction('p3', 3)
            sage: p3(x)
            x^3
            sage: loads(dumps(cot)) == cot    # trac #15138
            True
        """
        # check if already defined
        cdef int serial = -1

        # search ginac registry for name and nargs
        try:
            serial = find_function(str_to_bytes(self._name), self._nargs)
        except RuntimeError as err:
            pass

        # if match, get operator from function table
        global sfunction_serial_dict
        if serial != -1 and serial in sfunction_serial_dict and \
                sfunction_serial_dict[serial].__class__ == self.__class__:
                    # if the returned function is of the same type
                    self._serial = serial
                    return True

        return False

    def _evalf_or_eval_(self, *args):
        """
        First try to call :meth:`_evalf_` and return the result if it
        was not ``None``. Otherwise, call :meth:`_eval0_`, which is the
        original version of :meth:`_eval_` saved in :meth:`__init__`.
        """
        res = self._evalf_try_(*args)
        if res is None:
            return self._eval0_(*args)
        else:
            return res

    def __reduce__(self):
        """
        EXAMPLES::

            sage: cot.__reduce__()
            (<class 'sage.functions.trig.Function_cot'>, ())

            sage: f = loads(dumps(cot)) #indirect doctest
            sage: f(pi/2)
            0
        """
        return self.__class__, tuple()

    # this is required to read old pickles of erf, elliptic_ec, etc.
    def __setstate__(self, state):
        """
        EXAMPLES::

            sage: cot.__setstate__([1,0])
            Traceback (most recent call last):
            ...
            ValueError: cannot read pickle
            sage: cot.__setstate__([0]) #don't try this at home
        """
        if state[0] == 0:
            # old pickle data
            # we call __init__ since Python only allocates the class and does
            # not call __init__ before passing the pickled state to __setstate__
            self.__init__()
        else:
            # we should never end up here
            raise ValueError("cannot read pickle")


cdef class SymbolicFunction(Function):
    """
    This is the basis for user defined symbolic functions. We try to pickle or
    hash the custom methods, so subclasses must be defined in Python not Cython.
    """
    def __init__(self, name, nargs=0, latex_name=None, conversions=None,
            evalf_params_first=True):
        """
        EXAMPLES::

            sage: from sage.symbolic.function import SymbolicFunction
            sage: class my_function(SymbolicFunction):
            ....:     def __init__(self):
            ....:         SymbolicFunction.__init__(self, 'foo', nargs=2)
            ....:     def _evalf_(self, x, y, parent=None, algorithm=None):
            ....:         return x*y*2r
            ....:     def _conjugate_(self, x, y):
            ....:         return x
            sage: foo = my_function()
            sage: foo
            foo
            sage: foo(2,3)
            foo(2, 3)
            sage: foo(2,3).n()
            12.0000000000000
            sage: foo(2,3).conjugate()
            2
        """
        self.__hinit = False
        Function.__init__(self, name, nargs, latex_name, conversions,
                evalf_params_first)


    cdef _is_registered(SymbolicFunction self):
        # see if there is already a SymbolicFunction with the same state
        cdef Function sfunc
        cdef long myhash = self._hash_()
        for sfunc in sfunction_serial_dict.itervalues():
            if isinstance(sfunc, SymbolicFunction) and \
                    myhash == (<SymbolicFunction>sfunc)._hash_():
                # found one, set self._serial to be a copy
                self._serial = sfunc._serial
                return True

        return False

    # cache the hash value of this function
    # this is used very often while unpickling to see if there is already
    # a function with the same properties
    cdef long _hash_(self) except -1:
        if not self.__hinit:
            # create a string representation of this SymbolicFunction
            slist = [self._nargs, self._name, str(self._latex_name),
                    self._evalf_params_first]
            for fname in sfunctions_funcs:
                real_fname = '_%s_'%fname
                if hasattr(self, '%s'%real_fname):
                    slist.append(hash(getattr(self, real_fname).__code__))
                else:
                    slist.append(' ')
            self.__hcache = hash(tuple(slist))
            self.__hinit = True
        return self.__hcache

    def __hash__(self):
        """
        TESTS::

            sage: foo = function("foo", nargs=2)
            sage: hash(foo)      # random output
            -6859868030555295348

            sage: def ev(self, x): return 2*x
            sage: foo = function("foo", nargs=2, eval_func = ev)
            sage: hash(foo)      # random output
            -6859868030555295348
        """
        return self._serial*self._hash_()

    def __getstate__(self):
        """
        Return a tuple describing the state of this object for pickling.

        Pickling :class:`SymbolicFunction` objects is limited by the ability to pickle
        functions in python. We use :func:`~sage.misc.fpickle.pickle_function` for
        this purpose, which only works if there are no nested functions.


        This should return all information that will be required to unpickle
        the object. The functionality for unpickling is implemented in
        :meth:`__setstate__`.

        In order to pickle :class:`SymbolicFunction` objects, we return a tuple containing

         * 0  - as pickle version number
                in case we decide to change the pickle format in the feature
         * name of this function
         * number of arguments
         * latex_name
         * a tuple containing attempts to pickle the following optional
           functions, in the order below
           * ``eval_f``
           * ``evalf_f``
           * ``conjugate_f``
           * ``real_part_f``
           * ``imag_part_f``
           * ``derivative_f``
           * ``power_f``
           * ``series_f``
           * ``print_f``
           * ``print_latex_f``

        EXAMPLES::

            sage: foo = function("foo", nargs=2)
            sage: foo.__getstate__()
            (2, 'foo', 2, None, {}, True, [None, None, None, None, None, None, None, None, None, None, None])
            sage: t = loads(dumps(foo))
            sage: t == foo
            True
            sage: var('x,y')
            (x, y)
            sage: t(x,y)
            foo(x, y)

            sage: def ev(self, x,y): return 2*x
            sage: foo = function("foo", nargs=2, eval_func = ev)
            sage: foo.__getstate__()
            (2, 'foo', 2, None, {}, True, [..., None, None, None, None, None, None, None, None, None, None])

            sage: u = loads(dumps(foo))
            sage: u == foo
            True
            sage: t == u
            False
            sage: u(y,x)
            2*y

            sage: def evalf_f(self, x, **kwds): return int(6)
            sage: foo = function("foo", nargs=1, evalf_func=evalf_f)
            sage: foo.__getstate__()
            (2, 'foo', 1, None, {}, True, [None, ..., None, None, None, None, None, None, None, None, None])

            sage: v = loads(dumps(foo))
            sage: v == foo
            True
            sage: v == u
            False
            sage: foo(y).n()
            6
            sage: v(y).n()
            6

        Test pickling expressions with symbolic functions::

            sage: u = loads(dumps(foo(x)^2 + foo(y) + x^y)); u
            foo(x)^2 + x^y + foo(y)
            sage: u.subs(y=0)
            foo(x)^2 + foo(0) + 1
            sage: u.subs(y=0).n()
            43.0000000000000
        """
        return (2, self._name, self._nargs, self._latex_name, self._conversions,
                self._evalf_params_first,
                [pickle_wrapper(getattr(self, '_%s_' % fname, None))
                 for fname in sfunctions_funcs])

    def __setstate__(self, state):
        """
        Initialize the state of the object from data saved in a pickle.

        During unpickling ``__init__`` methods of classes are not called, the saved
        data is passed to the class via this function instead.

        TESTS::

            sage: var('x,y')
            (x, y)
            sage: foo = function("foo", nargs=2)
            sage: bar = function("bar", nargs=1)
            sage: bar.__setstate__(foo.__getstate__())

        ::

            sage: g = function('g', nargs=1, conjugate_func=lambda y,x: 2*x)
            sage: st = g.__getstate__()
            sage: f = function('f')
            sage: f(x)
            f(x)
            sage: f(x).conjugate() # no special conjugate method
            conjugate(f(x))
            sage: f.__setstate__(st)
            sage: f(x+1).conjugate() # now there is a special method
            2*x + 2

        Note that the other direction doesn't work here, since ``foo._hash_()``
        hash already been initialized.::

            sage: bar
            foo
            sage: bar(x,y)
            foo(x, y)
        """
        # check input
        if not ((state[0] == 1 and len(state) == 6) or \
                (state[0] == 2 and len(state) == 7)):
            raise ValueError("unknown state information")

        name = state[1]
        nargs = state[2]
        latex_name = state[3]
        conversions = state[4]

        if state[0] == 1:
            evalf_params_first = True
            function_pickles = state[5]
        elif state[0] == 2:
            evalf_params_first = state[5]
            function_pickles = state[6]

        for pickle, fname in zip(function_pickles, sfunctions_funcs):
            if pickle:
                real_fname = '_%s_'%fname
                setattr(self, real_fname, unpickle_function(pickle))

        SymbolicFunction.__init__(self, name, nargs, latex_name,
                conversions, evalf_params_first)


def get_sfunction_from_serial(serial):
    """
    Return an already created :class:`SymbolicFunction` given the serial.

    These are stored in the dictionary ``sage.symbolic.function.sfunction_serial_dict``.

    EXAMPLES::

        sage: from sage.symbolic.function import get_sfunction_from_serial
        sage: get_sfunction_from_serial(65) #random
        f
    """
    global sfunction_serial_dict
    return sfunction_serial_dict.get(serial)

def pickle_wrapper(f):
    """
    Return a pickled version of the function ``f``.

    If ``f`` is ``None``, just return ``None``.

    This is a wrapper around :func:`pickle_function`.

    EXAMPLES::

        sage: from sage.symbolic.function import pickle_wrapper
        sage: def f(x): return x*x
        sage: isinstance(pickle_wrapper(f), bytes)
        True
        sage: pickle_wrapper(None) is None
        True
    """
    if f is None:
        return None
    return pickle_function(f)

def unpickle_wrapper(p):
    """
    Return a unpickled version of the function defined by ``p``.

    If ``p`` is ``None``, just return ``None``.

    This is a wrapper around :func:`unpickle_function`.

    EXAMPLES::

        sage: from sage.symbolic.function import pickle_wrapper, unpickle_wrapper
        sage: def f(x): return x*x
        sage: s = pickle_wrapper(f)
        sage: g = unpickle_wrapper(s)
        sage: g(2)
        4
        sage: unpickle_wrapper(None) is None
        True
    """
    if p is None:
        return None
    return unpickle_function(p)

