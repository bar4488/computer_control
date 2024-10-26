def assert_list_of(arg, value_type):
    assert arg is not None
    assert isinstance(arg, list)
    assert all([isinstance(i, str) for i in arg])